import cors from 'cors';
import * as fs from 'fs';
import path from 'path';
import express from 'express';
import {download} from './download';
import {render} from './render';

export function createServer() {
  const app = express();

  app.use(express.json({limit: '50mb'}));
  app.use(cors());

  // Listar proyectos disponibles
  app.get('/projects', (req, res) => {
    const projectsDir = process.env.PROJECTS_DIR || './projects';
    const defaultProject = process.env.PROJECT_FILE?.split('/')?.[2] || 'default';

    try {
      const projects: string[] = [];

      // Leer directorios en projects/
      if (fs.existsSync(projectsDir)) {
        const dirs = fs.readdirSync(projectsDir);
        for (const dir of dirs) {
          const projectPath = path.join(projectsDir, dir);
          const projectFile = path.join(projectPath, 'src', 'project.ts');

          // Verificar que es un directorio y tiene project.ts
          if (
            fs.statSync(projectPath).isDirectory() &&
            fs.existsSync(projectFile)
          ) {
            projects.push(dir);
          }
        }
      }

      res.json({
        projects: projects.length > 0 ? projects : [defaultProject],
        default: defaultProject,
      });
    } catch (error: any) {
      console.error('Error listando proyectos:', error);
      res.status(500).json({
        status: 'error',
        message: 'Error listando proyectos',
      });
    }
  });

  // Renderizar proyecto específico
  app.post('/render/:projectName', async (req, res) => {
    const projectName = req.params.projectName;
    const projectsDir = process.env.PROJECTS_DIR || './projects';
    const projectFile = path.join(projectsDir, projectName, 'src', 'project.ts');

    // Verificar que el proyecto existe
    if (!fs.existsSync(projectFile)) {
      return res.status(404).json({
        status: 'error',
        message: `Proyecto "${projectName}" no encontrado`,
      });
    }

    // Modificar request para incluir projectFile
    req.body.projectFile = projectFile;
    req.body.projectName = projectName;

    // Llamar a render con el projectFile modificado
    return render(req, res);
  });

  // Renderizar proyecto default
  app.post('/render', render);

  // Descargar video renderizado
  app.get('/download/:projectName', download);

  return app;
}
