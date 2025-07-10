FROM ubuntu:22.04

# Install system libraries
RUN apt-get update && \
    apt-get install -y \
        python3 python3-pip wget ca-certificates \
        libgl1 libxcb1 libx11-6 libxrender1 libxext6 libsm6 && \
    apt-get clean

WORKDIR /app

# Copy app code
COPY requirements.txt .
COPY main.py .

# Install dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# ✅ Download and unpack FreeCAD 0.21.0 AppImage from SourceForge
RUN wget https://sourceforge.net/projects/free-cad/files/0.21.0/FreeCAD_0.21.0-Linux-x86_64.AppImage/download -O FreeCAD.AppImage && \
    chmod +x FreeCAD.AppImage && \
    ./FreeCAD.AppImage --appimage-extract

# Set environment for FreeCAD modules
ENV PYTHONPATH="/app/squashfs-root/usr/lib/python3.10/site-packages:/app/squashfs-root/usr/lib"
ENV PATH="/app/squashfs-root/usr/bin:$PATH"

# Run the API
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "10000"]
