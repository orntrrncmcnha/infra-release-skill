#!/usr/bin/env bash
set -euo pipefail

SKILL_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_NAME="infra-release"
SKILLS_DIR="${HOME}/.claude/skills"
LINK_PATH="${SKILLS_DIR}/${SKILL_NAME}"

if [ ! -f "${SKILL_SRC}/SKILL.md" ]; then
  echo "ERRO: SKILL.md não encontrado em ${SKILL_SRC}" >&2
  exit 1
fi
grep -q '^name:' "${SKILL_SRC}/SKILL.md" || { echo "ERRO: SKILL.md sem 'name:' no frontmatter" >&2; exit 1; }

mkdir -p "${SKILLS_DIR}"

if [ -L "${LINK_PATH}" ]; then
  ln -sfn "${SKILL_SRC}" "${LINK_PATH}"
  echo "Symlink atualizado: ${LINK_PATH} -> ${SKILL_SRC}"
elif [ -e "${LINK_PATH}" ]; then
  echo "ERRO: ${LINK_PATH} existe e não é symlink. Remova manualmente." >&2
  exit 1
else
  ln -s "${SKILL_SRC}" "${LINK_PATH}"
  echo "Instalado: ${LINK_PATH} -> ${SKILL_SRC}"
fi

echo "OK: skill '${SKILL_NAME}' pronto. Reinicie a sessão do Claude Code para detectar."
