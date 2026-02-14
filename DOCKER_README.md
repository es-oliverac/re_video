# Revideo Docker - EasyPanel Deployment

Esta guía explica cómo desplegar Revideo en EasyPanel usando Docker Compose con soporte para múltiples proyectos y renderizado paralelo.

## Arquitectura

```
revideo-main/
├── Dockerfile              # Imagen Docker multi-stage
├── docker-compose.yml        # Configuración Docker Compose
├── .env.example            # Variables de entorno ejemplo
├── easypanel.json         # Template EasyPanel
├── projects/               # Directorio de proyectos (volumen)
│   └── default/            # Proyecto default
│       └── src/
│           ├── project.ts
│           ├── example.tsx
│           └── global.css
├── output/                 # Directorio de salida (volumen)
└── scripts/
    └── init-projects.js    # Script para crear nuevos proyectos
```

## Configuración

### 1. Variables de Entorno

Copiar `.env.example` a `.env` y configurar:

```env
# Configuración del servidor
REVIDEO_PORT=4000
NODE_ENV=production

# Configuración de renderizado
WORKERS=8              # Número de workers paralelos (1-16)
PROJECTS_DIR=/app/projects

# Límites de recursos
CPU_LIMIT=4
CPU_RESERVATION=2
MEMORY_LIMIT=8G
MEMORY_RESERVATION=4G

# Telemetría
DISABLE_TELEMETRY=true
```

### 2. Construir Imagen Docker

```bash
docker-compose build
```

### 3. Iniciar Servicios

```bash
docker-compose up -d
```

## API Endpoints

### 1. Listar Proyectos

```
GET /projects
```

**Respuesta**:
```json
{
  "projects": ["default", "project2", "project3"],
  "default": "default"
}
```

### 2. Renderizar Video (Proyecto Default)

```
POST /render
Content-Type: application/json

{
  "variables": {
    "fill": "red",
    "repoName": "Mi Video"
  },
  "settings": {
    "workers": 8,
    "outFile": "mi-video.mp4"
  }
}
```

**Respuesta**:
```json
{
  "status": "success",
  "downloadLink": "http://localhost:4000/download/mi-video.mp4"
}
```

### 3. Renderizar Video (Proyecto Específico)

```
POST /render/:projectName
Content-Type: application/json

POST /render/my-project
{
  "variables": {
    "title": "Título Personalizado"
  },
  "settings": {
    "workers": 4
  }
}
```

### 4. Descargar Video

```
GET /download/:filename
```

Ejemplo:
```
GET /download/mi-video.mp4
```

### 5. Renderizar con Callback (Asincrónico)

```
POST /render
Content-Type: application/json

{
  "variables": {...},
  "settings": {...},
  "callbackUrl": "https://mi-servicio.com/webhook"
}
```

**Respuesta Inmediata**:
```json
{
  "tempProjectName": "uuid-del-proyecto"
}
```

**Callback cuando termina**:
```json
POST https://mi-servicio.com/webhook
{
  "tempProjectName": "uuid-del-proyecto",
  "status": "success",
  "downloadLink": "http://localhost:4000/download/video.mp4"
}
```

### 6. Renderizar con Streaming (Server-Sent Events)

```
POST /render
Content-Type: application/json

{
  "variables": {...},
  "streamProgress": true
}
```

Responde con eventos SSE:
```
event: progress
data: {"worker": 0, "progress": 0.25}

event: progress
data: {"worker": 1, "progress": 0.50}

event: completed
data: {"status": "success", "downloadLink": "..."}
```

## Crear Nuevos Proyectos

### Usando el Script

```bash
node scripts/init-projects.js mi-proyecto
```

Esto crea:
```
projects/
└── mi-proyecto/
    ├── src/
    │   ├── project.ts
    │   ├── example.tsx
    │   └── global.css
    ├── package.json
    ├── tsconfig.json
    └── vite.config.ts
```

### Manualmente

1. Crear directorio en `projects/`:
```
mkdir projects/mi-proyecto/src
```

2. Copiar archivos desde `projects/default/`:
```
cp -r projects/default/src/* projects/mi-proyecto/src/
```

3. Editar `projects/mi-proyecto/src/project.ts` para configurar el proyecto

## Despliegue en EasyPanel

### Opción 1: Usar Docker Compose

1. Subir código a repositorio Git
2. En EasyPanel:
   - Crear servicio desde "Docker Compose"
   - Configurar volumenes:
     * `./projects` → `/app/projects`
     * `./output` → `/app/output`
   - Configurar puerto: `4000`
   - Configurar recursos:
     * CPU: 4 cores (mínimo 2)
     * RAM: 8GB (mínimo 4GB)
   - Configurar variables de entorno

### Opción 2: Usar Template EasyPanel

1. Usar `easypanel.json` como template
2. Configurar:
   - Volumenes projects/ y output/
   - Variables de entorno (WORKERS, CPU, memoria)
   - Puerto 4000

### Verificación de Despliegue

1. Verificar que el contenedor esté corriendo:
```
docker-compose ps
```

2. Verificar health check:
```
curl http://localhost:4000/render
```

3. Probar listado de proyectos:
```
curl http://localhost:4000/projects
```

4. Probar renderizado:
```bash
curl -X POST http://localhost:4000/render \
  -H "Content-Type: application/json" \
  -d '{"variables": {"fill": "blue"}, "settings": {"workers": 8}}'
```

## Rendimiento y Recursos

### Requisitos Mínimos

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4GB | 8GB+ |
| Disco | 10GB | 20GB+ |

### Workers Paralelos

- **1-2 workers**: Para videos cortos (<10s)
- **4-8 workers**: Para videos medianos (10-60s) - **DEFAULT**
- **8-16 workers**: Para videos largos (60s+) - necesita más recursos

Cada worker usa:
- 1 puerto Vite (9000+N)
- ~500MB-1GB RAM
- ~10-20% CPU

### Optimizaciones

1. **Usar volumenes** para `projects/` y `output/` para evitar copiar archivos
2. **Ajustar workers** según longitud del video
3. **Usar callback** para videos largos (evita timeouts)
4. **Configurar recursos** en docker-compose para limitar uso

## Troubleshooting

### Error: "Project not found"

- Verificar que el proyecto existe en `projects/`
- Verificar que tiene `src/project.ts`
- Verificar que el directorio es accesible desde el contenedor

### Error: "Cannot find module"

- Construir la imagen Docker nuevamente
- Verificar que node_modules sea un volumen (no se recree)

### Videos muy lentos

- Aumentar número de workers
- Aumentar límites de CPU/RAM
- Verificar que no hay cuellos de botella en I/O

### Memory errors

- Reducir número de workers
- Aumentar límite de memoria
- Verificar que Puppeteer usa `--single-process` (por defecto)

## Seguridad

### Producción

1. **HTTPS**: Usar proxy reverso (Nginx, Traefik) con HTTPS
2. **Autenticación**: Agregar middleware de autenticación en Express
3. **Rate Limiting**: Limitar número de requests concurrentes
4. **Firewall**: No exponer puertos Vite (solo 4000)
5. **Telemetría**: Desabilitar con `DISABLE_TELEMETRY=true`

### Variables de Entorno Sensibles

No incluir en commits:
- `.env` (usar `.env.example` como template)
- API keys o credenciales
- Tokens de autenticación

## Ejemplos de Uso

### curl

```bash
# Renderizar video
curl -X POST http://localhost:4000/render \
  -H "Content-Type: application/json" \
  -d '{"variables": {"fill": "red"}, "settings": {"workers": 8}}'

# Listar proyectos
curl http://localhost:4000/projects

# Descargar video
curl -O http://localhost:4000/download/video.mp4
```

### JavaScript/Fetch

```javascript
// Renderizar video
const response = await fetch('http://localhost:4000/render', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({
    variables: {fill: 'blue'},
    settings: {workers: 8}
  })
});

const {status, downloadLink} = await response.json();

// Descargar video
window.location.href = downloadLink;
```

### Python

```python
import requests

# Renderizar video
response = requests.post('http://localhost:4000/render', json={
    'variables': {'fill': 'green'},
    'settings': {'workers': 8}
})

data = response.json()
print(f"Status: {data['status']}")
print(f"Download link: {data['downloadLink']}")

# Descargar video
video = requests.get(data['downloadLink'])
with open('video.mp4', 'wb') as f:
    f.write(video.content)
```

## Soporte

- **Documentación**: https://docs.re.video/
- **Discord**: https://discord.gg/hexYBZGBY8
- **Issues**: https://github.com/havenhq/revideo/issues
