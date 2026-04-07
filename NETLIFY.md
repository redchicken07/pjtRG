# pjtRG Netlify deploy notes

## Build settings

- Build command: `sh scripts/netlify-build.sh`
- Publish directory: `build/web`

## Optional environment variables

- `FLUTTER_CHANNEL`: defaults to `stable`
- `FLUTTER_ROOT`: defaults to `$HOME/flutter-sdk`
- `NETLIFY_BUILD_HOOK_URL`: used for manual redeploys

## Manual redeploy

```bash
sh scripts/trigger-netlify-build.sh
```
