FROM ubuntu:22.04

# Set up basic packages
RUN apt-get update && \
    apt-get install -y python3 python3-pip wget libgl1 libxcb1 libx11-6 libxrender1 libxext6 libsm6 && \
    apt-get clean

WORKDIR /app

COPY requirements.txt .
COPY main.py .

RUN pip3 install --no-cache-dir -r requirements.txt

# ✅ Corrected AppImage URL
RUN wget https://github.com/FreeCAD/FreeCAD/releases/download/0.21.2/FreeCAD-0.21.2-Linux-x86_64.AppImage -O FreeCAD.AppImage && \
    chmod +x FreeCAD.AppImage && \
    ./FreeCAD.AppImage --appimage-extract

ENV PYTHONPATH="/app/squashfs-root/usr/lib/python3.10/site-packages:/app/squashfs-root/usr/lib"

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "10000"]
