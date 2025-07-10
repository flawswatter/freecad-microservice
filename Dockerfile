# Use a minimal Python base image
FROM python:3.10-slim

# Install required system packages
RUN apt-get update && \
    apt-get install -y wget libgl1 libxrender1 libxext6 libsm6 libx11-6 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxi6 libxtst6 libxrandr2 libxxf86vm1 libxinerama1 libglu1-mesa && \
    apt-get clean

# Set the working directory
WORKDIR /app

# Copy project files
COPY requirements.txt .
COPY main.py .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# ✅ Download and extract FreeCAD AppImage (corrected link)
RUN wget https://github.com/FreeCAD/FreeCAD/releases/download/0.21.2/FreeCAD-0.21.2-Linux-x86_64.AppImage -O FreeCAD.AppImage && \
    chmod +x FreeCAD.AppImage && \
    ./FreeCAD.AppImage --appimage-extract

# Set environment variable so FreeCAD modules can be found
ENV PYTHONPATH="/app/squashfs-root/usr/lib/python3.10/site-packages:/app/squashfs-root/usr/lib"

# Set default command
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "10000"]
