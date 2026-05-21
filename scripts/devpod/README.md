# ejecucion para la creacion de devcontainer para manejo compartido o personal con devpod

## estructura

```bash
~/dotfiles/scripts/devpod/
├── init-devpod.sh          # entry point — detecta modo A o B
├── lib/
│   ├── detect.sh           # detecta tipo de proyecto
│   ├── read_project.sh     # lee devcontainer.json existente
│   ├── gen_dockerfile.sh   # genera Dockerfile personal
│   ├── gen_devcontainer.sh # genera devcontainer.json personal
│   ├── gen_team.sh         # genera devcontainer.json del equipo (modo B)
│   └── utils.sh            # colores, helpers
└── templates/
    ├── java.json            # features base para Java
    ├── node.json            # features base para Node/React
    └── flutter.stub         # placeholder Flutter
```

```bash
init-devpod.sh
  ├── utils.sh (colores, helpers)
  ├── detect.sh
  │     ├── ¿existe .devcontainer/devcontainer.json? → Modo A
  │     └── ¿no existe? → Modo B
  │           ├── pom.xml → java
  │           ├── package.json → node
  │           ├── pubspec.yaml → flutter (stub)
  │           └── ninguno → preguntar
  │
  ├── Modo A: read_project.sh → extrae features/puertos/env
  │           gen_dockerfile.sh
  │           gen_devcontainer.sh (personal)
  │
  └── Modo B: gen_team.sh (equipo, solo VS Code por ahora)
              gen_dockerfile.sh
              gen_devcontainer.sh (personal)
```

## modos de ejecucion

```bash
init-devpod.sh                    # interactivo, detecta automático
init-devpod.sh --mode personal    # solo genera .devcontainer-devpod/
init-devpod.sh --mode team        # solo genera .devcontainer/
init-devpod.sh --mode both        # genera ambos
init-devpod.sh --force            # sobreescribe sin preguntar
```

> **Modo team genera:**
> .devcontainer/
> └── devcontainer.json # image + features + puertos + remoteEnv básico
>
> **Modo personal genera:**
> .devcontainer-devpod/
> ├── Dockerfile # FROM devbox-base:latest + build.args
> └── devcontainer.json # features + puertos + remoteEnv + postCreateCommand
