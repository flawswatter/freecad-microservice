FROM ubuntu:22.04

# Install system dependencies
RUN apt-get update && \
    apt-get install -y \
        python3 \
        python3-pip \
        wget \
        ca-certificates \
        git \
        libgl1 \
        libxcb1 \
        libx11-6 \
        libxrender1 \
        libxext6 \
        libsm6 \
        libqt5core5a \
        libqt5gui5 \
        libqt5network5 \
        && apt-get clean


# ✅ NEW BLOCK
# Install git for cloning SheetMetal
RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy app source
COPY requirements.txt .
COPY main.py .

# Install Python packages
RUN pip3 install --no-cache-dir -r requirements.txt

# ✅ Download and unpack FreeCAD 0.21.0 AppImage (confirmed working)
RUN wget https://sourceforge.net/projects/free-cad/files/0.21.0/FreeCAD_0.21.0-Linux-x86_64.AppImage/download -O FreeCAD.AppImage && \
    chmod +x FreeCAD.AppImage && \
    ./FreeCAD.AppImage --appimage-extract

    # Clone the SheetMetal module manually
RUN git clone https://github.com/shaise/FreeCAD_SheetMetal.git /app/Mod/SheetMetal

# Set FreeCAD module path
ENV FREECAD_MOD_PATH=/app/Mod

# ✅ Set FreeCAD-only libraries (exclude site-packages to avoid conflict)
ENV PYTHONPATH="/app/squashfs-root/usr/lib:/app"
ENV PATH="/app/squashfs-root/usr/bin:$PATH"

# Start the API
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "10000"]
