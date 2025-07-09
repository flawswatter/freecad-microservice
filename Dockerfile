FROM ubuntu:22.04

# Install system dependencies required by FreeCAD
RUN apt-get update && apt-get install -y \
    wget \
    libgl1-mesa-glx \
    libxrender1 \
    libxext6 \
    libsm6 \
    libglu1-mesa \
    python3-pip \
    && apt-get clean

# Set working directory
WORKDIR /app

# Download and extract FreeCAD AppImage
RUN wget https://github.com/FreeCAD/FreeCAD/releases/download/0.21.2/FreeCAD_0.21.2-Linux-x86_64.AppImage -O FreeCAD.AppImage && \
    chmod +x FreeCAD.AppImage && \
    ./FreeCAD.AppImage --appimage-extract

# Install Python dependencies
COPY requirements.txt .
RUN pip3 install -r requirements.txt

# Copy your Python script
COPY main.py .

# Configure environment so FreeCAD modules are available
ENV LD_LIBRARY_PATH=/app/squashfs-root/usr/lib:$LD_LIBRARY_PATH
ENV PYTHONPATH=/app/squashfs-root/usr/lib/python3.10/site-packages:$PYTHONPATH

# Run your app using FreeCAD's embedded Python interpreter
CMD ["/app/squashfs-root/usr/bin/python3", "main.py"]
