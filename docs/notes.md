## Push a new tag to build and push a new Docker image
Pushing the tag triggers the `docker_publish.yml` github action workflow to run automatically. After merging your changes to `main`:
```bash
git checkout main
git pull
git tag -a v0.x.x -m "version 0.x.x"
git push origin v0.x.x
```

## Build and run locally

### Using Docker Compose (recommended)
```bash
# Start JupyterLab with integrated remote desktop
docker compose up --build

# Access JupyterLab at: http://localhost:8888
# Access the remote desktop via JupyterLab: http://localhost:8888/desktop
# (Click "Desktop" icon in JupyterLab launcher)

# Stop services
docker compose down
```

### Manual Docker commands
From the repo root:
```bash
DOCKER_BUILDKIT=1 docker build --progress=plain -t hefs-hub .

# Run JupyterLab (includes integrated remote desktop via jupyter-remote-desktop-proxy)
docker run -it --rm -p 8888:8888 hefs-hub:latest \
  jupyter lab --ip=0.0.0.0 --port=8888 --no-browser \
  --NotebookApp.token='' --NotebookApp.password=''

# For interactive shell access
docker run -it --rm -p 8888:8888 hefs-hub:latest /bin/bash
```

You can pass in your AWS credentials for local testing as well during the docker build:
```bash
docker build  --build-arg AWS_ACCESS_KEY_ID="..." --build-arg AWS_SECRET_ACCESS_KEY="..."  -t hefs-hub .
```

## Notes on the Dockerfile and other notes
- The FEWS binary is copied in as a zip file and extracted on lines 66-68.
- The dashboard is a Panel dashboard that is built from the `dashboard.ipynb` Jupyter Notebook in the `scripts` directory. The notebook also makes use of the `dashboard_funcs.py` module.
- The dashboard is started by running the `start_dashboard.sh` shell script, which can be called by `dashboard.desktop`
- The current `develop` branch contains some code experimenting with jupyter server proxy as a method for deploying the dashboard, which I could not get to work.
