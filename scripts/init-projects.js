#!/usr/bin/env node

/**
 * Script para inicializar nuevos proyectos de Revideo
 * Uso: node scripts/init-projects.js <nombre-proyecto>
 */

const fs = require('fs');
const path = require('path');

const PROJECTS_DIR = path.join(process.cwd(), 'projects');
const TEMPLATE_DIR = path.join(process.cwd(), 'projects', 'default');

function createProject(projectName) {
  if (!projectName) {
    console.error('Error: Debes proporcionar un nombre de proyecto');
    console.log('Uso: node scripts/init-projects.js <nombre-proyecto>');
    process.exit(1);
  }

  const projectDir = path.join(PROJECTS_DIR, projectName);

  // Verificar si el proyecto ya existe
  if (fs.existsSync(projectDir)) {
    console.error(`Error: El proyecto "${projectName}" ya existe`);
    process.exit(1);
  }

  // Crear directorio del proyecto
  fs.mkdirSync(projectDir, {recursive: true});
  fs.mkdirSync(path.join(projectDir, 'src'));

  // Copiar archivos desde template
  const filesToCopy = [
    'src/project.ts',
    'src/example.tsx',
    'src/global.css',
  ];

  filesToCopy.forEach(file => {
    const srcPath = path.join(TEMPLATE_DIR, file);
    const destPath = path.join(projectDir, file);

    if (fs.existsSync(srcPath)) {
      const content = fs.readFileSync(srcPath, 'utf-8');
      fs.writeFileSync(destPath, content, 'utf-8');
      console.log(`Creado: ${destPath}`);
    }
  });

  // Crear package.json para el proyecto
  const packageJson = {
    name: `revideo-${projectName}`,
    version: '1.0.0',
    private: true,
    scripts: {
      dev: 'vite',
      build: 'tsc && vite build',
      render: 'tsc && node dist/render.js',
    },
  };
  fs.writeFileSync(
    path.join(projectDir, 'package.json'),
    JSON.stringify(packageJson, null, 2),
    'utf-8',
  );

  // Crear tsconfig.json si es necesario
  const tsconfigJson = {
    extends: '../../tsconfig.json',
    compilerOptions: {
      outDir: './dist',
    },
    include: ['src/**/*'],
  };
  fs.writeFileSync(
    path.join(projectDir, 'tsconfig.json'),
    JSON.stringify(tsconfigJson, null, 2),
    'utf-8',
  );

  // Crear vite.config.ts
  const viteConfig = `import {defineConfig} from 'vite';

export default defineConfig({
  build: {
    lib: {
      entry: './src/project.ts',
      name: '${projectName}',
      fileName: 'project',
    },
  },
});
`;
  fs.writeFileSync(
    path.join(projectDir, 'vite.config.ts'),
    viteConfig,
    'utf-8',
  );

  console.log(`\nProyecto "${projectName}" creado exitosamente!`);
  console.log(`\nPróximos pasos:`);
  console.log(`1. Editar projects/${projectName}/src/project.ts para configurar tu proyecto`);
  console.log(`2. Agregar tus escenas en projects/${projectName}/src/`);
  console.log(`3. Renderizar con: curl -X POST http://localhost:4000/render/${projectName}`);
}

// Obtener nombre del proyecto desde argumentos
const projectName = process.argv[2];
createProject(projectName);
