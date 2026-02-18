# boe-auto

Automatización robusta para descargar el **Sumario del BOE** (Boletín Oficial del Estado de España) utilizando GitHub Actions y el paquete R de rOpenSpain/BOE.

## Objetivo

Generar un **endpoint estable** con GitHub Pages que sirva `docs/boe/latest.json` con los datos más recientes del sumario del BOE, actualizado automáticamente **3 veces al día** (10:00, 15:00 y 20:00 hora Europe/Madrid) sin necesidad de scraping HTML frágil.

## Características

- **Sin scraping HTML**: utiliza la función `BOE::retrieve_sumario()` del paquete oficial
- **Ejecución robusta**: si no hay BOE (p.ej. domingo) o hay error, no rompe el workflow
- **Auditoría completa**: histórico de ejecuciones en `docs/boe/run_*.json`
- **Deduplicación automática**: elimina registros duplicados por `publication` o por combinación `(text + pages)`
- **Ordenamiento consistente**: items ordenados por section, departament, epigraph
- **Endpoint estable**: GitHub Pages publica los JSON en URL pública
- **Timezone correcto**: todas las marcas de tiempo en Europe/Madrid

## Configuración

### 1. Activar GitHub Pages

1. Ve a **Settings** del repositorio
2. Baja a **Pages**
3. Selecciona:
   - Source: Deploy from a branch
   - Branch: `main`
   - Carpeta: `/docs`
4. Guarda y espera 1-2 minutos

### 2. Ejecutar workflow manual (opcional)

1. Ve a **Actions**
2. Selecciona el workflow **"BOE Sumario Download"**
3. Haz clic en **"Run workflow"**
4. Selecciona la rama `main` y ejecuta

## Endpoints disponibles

Una vez activo GitHub Pages, los archivos estarán disponibles en:

- **Última actualización**: `https://{tu-usuario}.github.io/{tu-repo}/boe/latest.json`
- **Histórico de ejecuciones**: `https://{tu-usuario}.github.io/{tu-repo}/boe/run_YYYY-MM-DDTHH-MM-SS.json`

Ejemplo (reemplaza `{tu-usuario}` y `{tu-repo}`):
```
https://albertoiglesiasfragagaming-ops.github.io/boe-auto/boe/latest.json
```

## Esquema JSON

### `latest.json`

```json
{
  "meta": {
    "date": "2026-02-18",
    "fetched_at_madrid": "2026-02-18 10:15:30 CET"
  },
  "status": "ok|no_items|error",
  "error": "..." ,
  "items": [
    {
      "section": "I. Disposiciones generales",
      "departament": "Ministerio de...",
      "epigraph": "Orden",
      "text": "Descripción de la disposición",
      "publication": "BOE-A-2026-12345",
      "pages": "1234-1245",
      "url": "..."
    }
  ]
}
```

### Campos en `items`

- **section**: sección del BOE
- **departament**: departamento/ministerio
- **epigraph**: tipo de disposición
- **text**: texto de la disposición
- **publication**: código BOE (p.ej. BOE-A-2026-12345)
- **pages**: páginas (si disponible)
- **url**: enlace (si disponible en el paquete BOE)

Nota: solo incluye campos que el paquete BOE proporciona; no se inventan campos adicionales.

### Estados en `status`

- **ok**: sumario descargado y procesado correctamente
- **no_items**: no hay BOE para esa fecha (p.ej. domingos)
- **error**: hubo un error; ver campo `error` para detalles

## Cómo ajustar los horarios

Edita el archivo `.github/workflows/boe.yml`:

```yaml
on:
  schedule:
    - cron: '0 * * * *'  # Ejecuta cada hora
```

El script R internamente verifica si la hora en Madrid es 10, 15 o 20. Si quieres cambiar los horarios:

1. Modifica el script `scripts/generate_boe_latest.R`, línea:
   ```r
   if (!(hour_madrid %in% c(10, 15, 20))) {
   ```
   Reemplaza `c(10, 15, 20)` con los horarios que desees (p.ej. `c(9, 12, 18)`)

2. El cron `0 * * * *` se mantiene (ejecuta cada hora) para máxima robustez

## Troubleshooting

### 1. Sin BOE (fines de semana o festivos)

**Síntoma**: `latest.json` con `status: "no_items"`

**Solución**: Es normal. El BOE no publica sumarios todos los días. Confirma en [BOE.es](https://www.boe.es) si hay publicaciones para esa fecha.

### 2. Error de instalación del paquete BOE

**Síntoma**: Workflow fallido, logs muestran error en `remotes::install_github('rOpenSpain/BOE')`

**Solución**:
- Revisa los logs del workflow (Actions > último run > logs)
- Comprueba si el paquete está disponible en GitHub: https://github.com/rOpenSpain/BOE
- Intenta re-ejecutar el workflow (a veces son errores temporales de red)
- Si persiste, contacta a rOpenSpain con los detalles del error

### 3. Rate limit HTTP 429

**Síntoma**: Logs muestran "429 Too Many Requests" o similar

**Solución**:
- El paquete BOE está siendo rate limitado por el servidor
- El workflow reintentará en la próxima ejecución (en 1 hora)
- No es un error fatal; es temporal

### 4. GitHub Pages no activo o URL 404

**Síntoma**: `https://{usuario}.github.io/{repo}/boe/latest.json` devuelve 404

**Solución**:
- Verifica que GitHub Pages esté activado en Settings > Pages
- Asegúrate de que la rama sea `main` y la carpeta `/docs`
- Espera 1-2 minutos después de activar Pages
- El repositorio debe ser **público** para que Pages funcione sin licencia Pro

### 5. Horario incorrecto (no ejecuta a las horas esperadas)

**Síntoma**: Workflow ejecutado pero `latest.json` no tiene cambios a la hora esperada

**Solución**:
- El workflow ejecuta cada hora, pero el script R verifica internamente si es 10/15/20 Madrid
- Verifica el timezone: el script fuerza `Europe/Madrid`, pero comprueba en los logs:
  ```
  Current hour in Madrid: XX. Not an execution hour (10, 15, 20). Exiting without changes.
  ```
- Si ves este mensaje, es correcto; el workflow se ejecutó pero no era hora de actualizar
- Para ver una actualización, espera a las 10:00, 15:00 o 20:00 CET/CEST
- En caso de que la zona horaria sea incorrecta, abre un issue en GitHub con los detalles

## Estructura del repositorio

```
boe-auto/
├── .github/
│   └── workflows/
│       └── boe.yml                    # Workflow GitHub Actions
├── scripts/
│   └── generate_boe_latest.R          # Script R de descarga y procesamiento
├── docs/
│   └── boe/
│       ├── latest.json                # Última actualización (publicado por Pages)
│       └── run_YYYY-MM-DDTHH-MM-SS.json  # Histórico de ejecuciones
├── README.md                          # Este archivo
```

## Referencias

- [Paquete R BOE - rOpenSpain](https://github.com/rOpenSpain/BOE)
- [BOE.es - Boletín Oficial del Estado](https://www.boe.es)
- [GitHub Actions](https://docs.github.com/en/actions)
- [GitHub Pages](https://pages.github.com/)

## Licencia

Este proyecto no tiene licencia específica. Usa libremente el código. El paquete BOE está bajo licencia del proyecto rOpenSpain.