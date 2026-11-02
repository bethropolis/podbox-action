## podbox images

| Image | Ref | Digest | Status |
|---|---|---|---|
| dev | `ghcr.io/me/repo/dev` | `sha256:aaaaaaaaaaaa` | skipped |
| gaming | `ghcr.io/me/repo/gaming` | `sha256:bbbbbbbbbbbb` | pushed |

Use the published image(s):

```bash
podbox create ghcr.io/me/repo/gaming:latest
```

> **First publish.** GHCR creates new packages as private. To let others pull
> without logging in, open each package, then *Package settings → Change
> visibility → Public* (one-time, and it cannot be reversed from public to private):
>
> - `ghcr.io/me/repo/gaming`
