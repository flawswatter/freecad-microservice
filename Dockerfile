FROM ubuntu:22.04

# Install system + Python deps
RUN apt-get update && apt-get install -y \
    wget \
    libgl1-mesa-glx \
    libxrender1 \
    libxext6 \
    libsm6 \
    libglu1-mesa \
    python3-pip \
    && apt-get clean

WORKDIR /app

# Download FreeCAD AppImage and extract it
RUN wget https://github.com/FreeCAD/FreeCAD/releases/download/0.21.2/FreeCAD-0.21.2-Linux-x86_64.AppImage -O FreeCAD.AppImage && \
    chmod +x FreeCAD.AppImage && \
    ./FreeCAD.AppImage --appimage-extract

# Install Python dependencies
COPY requirements.txt .
RUN pip3 install -r requirements.txt

# Copy your source code
COPY main.py .

# Set environment for FreeCAD modules
ENV LD_LIBRARY_PATH=/app/squashfs-root/usr/lib:$LD_LIBRARY_PATH
ENV PYTHONPATH=/app/squashfs-root/usr/lib/python3.10/site-packages:$PYTHONPATH
ENV FC_PATH=/app/squashfs-root/usr/Mod/SheetMetal

# ⛔️ Remove CMD running main.py directly
# ✅ Instead, start FastAPI with uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
