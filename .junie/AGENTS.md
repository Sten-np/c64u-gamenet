# C64U GameNet — Junie Project Guidelines

## Project purpose

C64U GameNet is a 6502 assembly networking library for Commodore 64
Ultimate systems. The long-term goal is to enable multiplayer
adaptations of existing C64 games running on separate C64 Ultimate
machines.

## Source of truth

- `roadmap.md` is the project roadmap and milestone source of truth.
- Reference material is stored under `docs/reference/`.
- For C64 Ultimate-specific behavior, prefer the C64 Ultimate User Guide.
- For 6502 assembly concepts, prefer the 6502 Assembly Language Programming reference.
- Do not invent hardware behavior when the project references can answer the question.

## Development rules

1. Work on one roadmap milestone at a time.
2. Do not start a later milestone unless explicitly requested.
3. Keep low-level hardware access separate from the public networking API.
4. Clearly document C64 Ultimate-specific behavior and assumptions.
5. Prefer simple, testable 6502 code.
6. Keep compatibility with a real C64 in mind where practical, while clearly identifying C64 Ultimate requirements.
7. Verify generated binaries/build artifacts whenever possible.
8. Update documentation when behavior or architecture changes.
9. Do not silently replace project-reference information with generic model knowledge.
10. When the references do not establish an answer, say so and identify what needs verification.

## Current workflow

Read `roadmap.md` before beginning substantial work. Complete the
current milestone, test it, document it, and only then move to the next
milestone.
