## Objetivo de la usuaria
<!-- Explica en lenguaje claro qué problema resuelve esta propuesta o qué nueva automatización habilita. -->


## Archivos modificados
<!-- Lista los archivos de código, scripts o configuración segura incluidos en la rama `proposal/*`. -->
- 

## Checklist de Seguridad Local: sin .env, sin tokens OAuth, sin datos personales
- [ ] Verificado con `git status --ignored` que los secretos y datos personales siguen excluidos.
- [ ] Verificado con `git diff --cached --name-only` que no se incluyeron archivos `.env` ni `.env.*`.
- [ ] Confirmado cero tokens OAuth, llaves (`*.pem`, `*.key`) ni archivos `*credentials*.json` / `*token*.json`.
- [ ] Confirmado cero bases de datos locales (`*.db`, `*.sqlite*`) ni carpetas personales (`user_data/`, `private/`, `uploads/`).
- [ ] Cambios probados localmente junto con la usuaria antes de abrir este Pull Request.
