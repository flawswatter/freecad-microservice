from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse, PlainTextResponse
import os
import tempfile
import traceback
import importlib.util
import sys

# Setup FreeCAD paths for AppImage
sys.path.append("/app/squashfs-root/usr/lib")
sys.path.append("/app/squashfs-root/usr/Mod/SheetMetal")

import FreeCAD
import Part
import Import

# Try to load SheetMetal workbench
try:
    spec = importlib.util.spec_from_file_location(
        "SheetMetalUnfolder",
        "/app/squashfs-root/usr/Mod/SheetMetal/SheetMetalUnfolder.py"
    )
    SheetMetalUnfolder = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(SheetMetalUnfolder)
except Exception as e:
    SheetMetalUnfolder = None
    print("❌ Could not load SheetMetalUnfolder:", e)

app = FastAPI()

@app.get("/")
async def health_check():
    return {"status": "ok"}

@app.post("/unfold")
async def unfold(file: UploadFile = File(...)):
    tmp_path = None
    flat_dxf_path = None
    try:
        suffix = os.path.splitext(file.filename)[-1].lower()
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(await file.read())
            tmp_path = tmp.name

        doc = FreeCAD.newDocument()
        
        if suffix == ".dxf":
            Import.importDXF(tmp_path)
            obj = doc.Objects[-1]
        else:
            shape = Part.read(tmp_path)
            obj = doc.addObject("Part::Feature", "ImportedPart")
            obj.Shape = shape

        doc.recompute()

        flat_result = None
        dxf_data = None

        if SheetMetalUnfolder and obj:
            flat_obj = SheetMetalUnfolder.makeUnfold(obj)
            doc.recompute()
            flat_bb = flat_obj.Shape.BoundBox
            flat_result = {
                "flat_x_mm": flat_bb.XLength,
                "flat_y_mm": flat_bb.YLength
            }

            # Export DXF preview to temp file
            with tempfile.NamedTemporaryFile(delete=False, suffix=".dxf") as flat_file:
                flat_dxf_path = flat_file.name
            Import.export([flat_obj], flat_dxf_path)
            with open(flat_dxf_path, "r") as f:
                dxf_data = f.read()

        bbox = obj.Shape.BoundBox
        return JSONResponse({
            "bounding_box_mm": {
                "x": bbox.XLength,
                "y": bbox.YLength,
                "z": bbox.ZLength
            },
            "flat_pattern": flat_result,
            "flat_dxf": dxf_data
        })

    except Exception as e:
        return JSONResponse(status_code=500, content={
            "error": "Unfolding failed",
            "details": traceback.format_exc()
        })
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)
        if flat_dxf_path and os.path.exists(flat_dxf_path):
            os.remove(flat_dxf_path)
