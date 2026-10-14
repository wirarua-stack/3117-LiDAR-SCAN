# Optional processing service

No backend is required for the MVP. If introduced, a FastAPI worker may accept an explicitly uploaded, encrypted mesh archive for non-real-time cleanup, simplification, texture projection, or feature-candidate generation. It must preserve the original capture, return derived artifacts with provenance, and never silently replace source geometry.

Open3D and any other processing dependency require a separate license, platform-compatibility, performance, and security review before adoption.
