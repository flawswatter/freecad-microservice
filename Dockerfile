FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-dev \
    freecad freecad-common \
    libgl1-mesa-glx libxrender1 libsm6 libxext6 \
    && apt-get clean

# Set FreeCAD module paths
ENV PYTHONPATH="/usr/lib/freecad/Mod:/usr/lib/python3/dist-packages"

WORKDIR /app
COPY . .

RUN pip install -r requirements.txt

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
