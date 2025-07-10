FROM ubuntu:22.04

# Set up system dependencies
RUN apt-get update && \
    apt-get install -y \
        python3 \
        python3-pip \
        wget \
        libgl1 \
        libxcb1 \
        libx11-6 \
        libxrender1 \
        libxext6 \
        libsm6 \
        ca-certificates && \
    apt-get clean

WORKDIR /app

# Copy your application code
COPY requirements.txt .
COPY main.py .

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# ✅ Download and extract FreeCAD 0.21.1 AppImage (with cert workaround)
RUN wget --no-check-certificate https://github.com/FreeCAD/FreeCAD/releases/download/0.21.1/FreeCAD-0.21.1-Linux-x86_64.AppImage -O FreeCAD.AppImage && \
    chmod +x FreeCAD.AppImage && \
    ./FreeCAD.AppImage --appimage-extract

# Set FreeCAD environment
ENV PYTHONPATH="/app/squashfs-root/usr/lib/python3.10/site-packages:/app/squashfs-root/usr/lib"
ENV PATH="/app/squashfs-root/usr/bin:$PATH"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "10000"]
