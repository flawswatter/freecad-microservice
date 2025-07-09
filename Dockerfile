FROM ubuntu:22.04

# Install system + Python deps
RUN apt-get update && apt-get install -y \
    wget \
    git \
    libgl1-mesa-glx \
    libxrender1 \
    libxext6 \
    libsm6 \
    libglu1-mesa \
    python3-pip \
    && apt-get clean

WORKDIR /app

# Download and extract FreeCAD AppImage
RUN wget https://github.com/FreeCAD/FreeCAD/releases/download/0.21.2/FreeCAD-0.21.2-Linux-x86_64.AppImage -O FreeCAD.AppImage && \
    chmod +x FreeCAD.AppImage && \
    ./FreeCAD.AppImage --appimage-extract

# 🛠️ Install SheetMetal module manually inside the AppImage mod folder
RUN git clone https://github.com/shaise/FreeCAD_SheetMetal.git /app/squashfs-root/usr/Mod/SheetMetal

# Install FastAPI + dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy API code
COPY main.py .

# FreeCAD environment config
ENV LD_LIBRARY_PATH=/app/squashfs-root/usr/lib:$LD_LIBRARY_PATH
ENV PYTHONPATH=/app/squashfs-root/usr/lib/python3.10/site-packages:$PYTHONPATH

# Start FastAPI server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
