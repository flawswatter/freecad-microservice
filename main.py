from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
import os
import tempfile
import traceback
import importlib.util
import sys

# ✅ Point to FreeCAD AppImage-extracted modules
sys.path.append("/app/squashfs-root/usr/lib")
sys.path.append("/app/squashfs-root/usr/Mod/SheetMetal")

# ✅ Import FreeCAD and Part
import FreeCAD
import Part

# ✅ Dynamically import SheetMetalUnfolder if available
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

@app.post("/unfold")
async def unfold(file: UploadFile = File(...)):
    try:
        suffix = os.path.splitext(file.filename)[-1]
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(await file.read())
            tmp_path = tmp.name

        doc = FreeCAD.newDocument()
        shape = Part.read(tmp_path)
        part_obj = doc.addObject("Part::Feature", "ImportedPart")
        part_obj.Shape = shape

        flat_result = None
        if SheetMetalUnfolder:
            flat_obj = SheetMetalUnfolder.makeUnfold(part_obj)
            doc.recompute()
            flat_result = {
                "flat_x_mm": flat_obj.Shape.BoundBox.XLength,
                "flat_y_mm": flat_obj.Shape.BoundBox.YLength
            }

        bbox = shape.BoundBox
        return JSONResponse({
            "bounding_box_mm": {
                "x": bbox.XLength,
                "y": bbox.YLength,
                "z": bbox.ZLength
            },
            "flat_pattern": flat_result
        })

    except Exception as e:
        return JSONResponse(status_code=500, content={
            "error": "Unfolding failed",
            "details": traceback.format_exc()
        })
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
