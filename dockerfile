# Base image
FROM ubuntu:22.04

# Disable interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Set working directory
WORKDIR /app

# Copy source files
COPY . .

# Debug (optional)
RUN echo "Listing contents:" && ls -l /app

# Install system dependencies
RUN apt-get update && apt-get install -y \\
    software-properties-common \\
    python3 \\
    python3-pip \\
    git \\
    wget \\
    libgl1 \\
    libxext6 \\
    libxrender1 \\
    libsm6 \\
    libx11-6 \\
    libxcb1 \\
    libmagic1 && \\
    apt-get clean

# Add FreeCAD PPA
RUN add-apt-repository ppa:freecad-maintainers/freecad-stable && \\
    apt-get update && \\
    apt-get install -y freecad && \\
    apt-get clean

# Clone and install SheetMetal Workbench
RUN mkdir -p /usr/share/freecad/Mod/SheetMetal && \\
    git clone https://github.com/shaise/FreeCAD_SheetMetal /usr/share/freecad/Mod/SheetMetal

# Set FreeCAD paths
ENV PYTHONPATH=/usr/lib/freecad-python3/lib:/usr/share/freecad/Mod/SheetMetal:/usr/lib/freecad/Mod:/usr/lib/freecad-python3/Mod
ENV LD_LIBRARY_PATH=/usr/lib/freecad-python3/lib:/lib/x86_64-linux-gnu
ENV PATH="/usr/bin/freecad:${PATH}"

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Expose FastAPI port
EXPOSE 8000

# Run app
CMD ["uvicorn", "main_freecad_hardened:app", "--host", "0.0.0.0", "--port", "8000"]
