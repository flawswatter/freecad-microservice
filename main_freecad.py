import sys
import os
import traceback
import importlib.util
import logging
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
import tempfile
import ezdxf
import magic
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from starlette.requests import Request
from starlette.responses import Response

# Logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# FreeCAD paths
sys.path.append("/usr/lib/freecad-python3/lib")
sys.path.append("/usr/share/freecad/Mod/SheetMetal")
sys.path.append("/usr/lib/freecad/Mod")
sys.path.append("/usr/lib/freecad-python3/Mod")
sys.path.append("/usr/share/freecad/Mod")
sys.path.append("/usr/lib/freecad/Mod/Draft/dxflibrary")

import FreeCAD
import Part
import Import
import Draft

# Handle import fallbacks
try:
    import importDXF
except ImportError:
    import types
    logger.error("importDXF not found, using fallback")
    importDXF = types.ModuleType("importDXF")
    importDXF.insert = Import.insert
    importDXF.export = Import.export
    sys.modules["importDXF"] = importDXF

try:
    import importSVG
except ImportError:
    import types
    logger.error("importSVG not found, using fallback")
    importSVG = types.ModuleType("importSVG")
    importSVG.insert = Import.insert
    importSVG.export = Import.export
    sys.modules["importSVG"] = importSVG

# Load SheetMetal
try:
    spec = importlib.util.spec_from_file_location(
        "SheetMetalUnfolder",
        "/usr/share/freecad/Mod/SheetMetal/SheetMetalUnfolder.py"
    )
    SheetMetalUnfolder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(SheetMetalUnfolder)
except Exception as e:
    SheetMetalUnfolder = None
    logger.error(f"Could not load SheetMetalUnfolder: {e}")
    logger.error(traceback.format_exc())

def mm_to_inches(val_mm, decimals=3):
    return round(val_mm * 0.0393701, decimals)

# App + limiter setup
app = FastAPI()
limiter = Limiter(key_func=get_remote_address, default_limits=["10/minute"])
app.state.limiter = limiter
app.add_middleware(SlowAPIMiddleware)

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return Response("Rate limit exceeded. Please slow down.", status_code=429)

@app.get("/")
def health():
    return {"status": "ok"}

@app.post("/unfold")
def unfold(file: UploadFile = File(...)):
    logger.info(f"Processing file: {file.filename}")
    tmp_path = flat_dxf_path = None
    try:
        # Enforce size limit
        file.file.seek(0, os.SEEK_END)
        size_mb = file.file.tell() / (1024 * 1024)
        file.file.seek(0)
        if size_mb > 2:
            return JSONResponse(status_code=413, content={"error": "File too large. Max 2MB"})

        # MIME check
        mime = magic.from_buffer(file.file.read(2048), mime=True)
        file.file.seek(0)
        if mime not in ["application/dxf", "application/octet-stream", "text/plain"]:
            return JSONResponse(status_code=415, content={"error": "Unsupported file type", "detected_mime": mime})

        suffix = os.path.splitext(file.filename)[-1].lower()
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(file.file.read())
            tmp_path = tmp.name

        doc = FreeCAD.newDocument()

        parsed_layers = []
        parsed_notes = []
        units_detected = "unknown"
        scaling_factor = 1.0

        if suffix == ".dxf":
            dxf_doc = ezdxf.readfile(tmp_path)
            header_vars = dxf_doc.header
            units = header_vars.get('$INSUNITS', 0)
            if units == 4:
                units_detected = "mm"
                scaling_factor = 0.03937
            elif units == 1:
                units_detected = "inch"
                scaling_factor = 1.0

            parsed_layers = [layer.dxf.name for layer in dxf_doc.layers]
            parsed_notes = [e.dxf.text for e in dxf_doc.query('TEXT')]

            if scaling_factor != 1.0:
                msp = dxf_doc.modelspace()
                for e in msp:
                    try:
                        e.scale_uniform(scaling_factor)
                    except Exception:
                        continue

            ascii_path = tmp_path + "_ascii.dxf"
            dxf_doc.saveas(ascii_path, encoding="utf-8")
            tmp_path = ascii_path
            Import.insert(tmp_path, doc.Name)
            obj = doc.Objects[-1]
        else:
            shape = Part.read(tmp_path)
            obj = doc.addObject("Part::Feature", "ImportedPart")
            obj.Shape = shape

        doc.recompute()

        flat_result = flat_pattern_in = dxf_data = None

        if SheetMetalUnfolder and obj:
            try:
                flat_obj = SheetMetalUnfolder.makeUnfold(obj)
                doc.recompute()
                flat_bb = flat_obj.Shape.BoundBox
                flat_result = {
                    "flat_x_mm": flat_bb.XLength,
                    "flat_y_mm": flat_bb.YLength
                }
                flat_pattern_in = {
                    "flat_x_in": mm_to_inches(flat_bb.XLength),
                    "flat_y_in": mm_to_inches(flat_bb.YLength)
                }
                with tempfile.NamedTemporaryFile(delete=False, suffix=".dxf") as flat_file:
                    flat_dxf_path = flat_file.name
                Import.export([flat_obj], flat_dxf_path)
                with open(flat_dxf_path, "r") as f:
                    dxf_data = f.read()
            except Exception as e:
                logger.error("Unfolding failed")
                logger.error(traceback.format_exc())
                return JSONResponse(status_code=500, content={"error": "Unfolding failed", "details": str(e)})

        bbox = obj.Shape.BoundBox
        thickness_mm = bbox.ZLength
        thickness_in = mm_to_inches(thickness_mm)

        customer_name = part_number = part_description = None
        for note in parsed_notes:
            note_lower = note.lower()
            if "customer" in note_lower:
                customer_name = note.split(":")[-1].strip()
            elif "part" in note_lower and "no" in note_lower:
                part_number = note.split(":")[-1].strip()
            elif "desc" in note_lower:
                part_description = note.split(":")[-1].strip()

        return JSONResponse({
            "flat_pattern": flat_result,
            "flat_pattern_in": flat_pattern_in,
            "thickness_mm": thickness_mm,
            "thickness_in": thickness_in,
            "parsed_layers": parsed_layers,
            "parsed_notes": parsed_notes,
            "dxf_units": units_detected,
            "customer_name": customer_name,
            "part_number": part_number,
            "part_description": part_description,
            "flat_dxf": dxf_data
        })

    except Exception as e:
        logger.error("Request failed")
        logger.error(traceback.format_exc())
        return JSONResponse(status_code=500, content={"error": "Request failed", "details": str(e)})
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)
        if flat_dxf_path and os.path.exists(flat_dxf_path):
            os.remove(flat_dxf_path)
