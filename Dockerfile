FROM ubuntu:22.04

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

# Download and extract FreeCAD AppImage
RUN wget https://github.com/FreeCAD/FreeCAD/releases/download/0.21.2/FreeCAD-0.21.2-Linux-x86_64.AppImage -O FreeCAD.AppImage && \
    chmod +x FreeCAD.AppImage && \
    ./FreeCAD.AppImage --appimage-extract

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy main source
COPY main.py .

# Set FreeCAD library paths
ENV LD_LIBRARY_PATH=/app/squashfs-root/usr/lib:$LD_LIBRARY_PATH
ENV PYTHONPATH=/app/squashfs-root/usr/lib/python3.10/site-packages:$PYTHONPATH

# Start FastAPI app using uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
