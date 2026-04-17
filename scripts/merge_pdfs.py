from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

import fitz
from pypdf import PdfWriter


@dataclass(frozen=True)
class RoleSpec:
    role: str
    label: str | None
    include_source_outline: bool


STAGE_ROLE_SPECS: dict[str, list[RoleSpec]] = {
    "blind": [
        RoleSpec("cover", "盲审封面", False),
        RoleSpec("en", None, True),
        RoleSpec("zh", None, True),
    ],
    "defense": [
        RoleSpec("cover", "中文封面", False),
        RoleSpec("en", None, True),
        RoleSpec("zh", None, True),
    ],
    "final": [
        RoleSpec("cover", "中文封面", False),
        RoleSpec("copyright", "版权声明", False),
        RoleSpec("en", None, True),
        RoleSpec("zh", None, True),
        RoleSpec("commitment", "终版学位论文承诺书", False),
        RoleSpec("originauth", "原创性声明和使用授权说明", False),
        RoleSpec("back_cover", "封底", False),
    ],
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Merge staged thesis PDFs and rebuild a clean outline tree."
    )
    parser.add_argument(
        "--stage",
        required=True,
        choices=sorted(STAGE_ROLE_SPECS.keys()),
        help="Build stage whose packet order determines the final bookmark tree.",
    )
    parser.add_argument("output", help="Merged output PDF path.")
    parser.add_argument("inputs", nargs="+", help="Input PDF paths in stage packet order.")
    return parser.parse_args()


def extract_outline(pdf_path: Path) -> list[tuple[int, str, int]]:
    entries: list[tuple[int, str, int]] = []
    with fitz.open(pdf_path) as doc:
        for item in doc.get_toc():
            if len(item) < 3:
                continue
            level, title, page_number = item[:3]
            if level < 1 or page_number < 1:
                continue
            entries.append((int(level), str(title).strip(), int(page_number)))
    return entries


def get_page_count(pdf_path: Path) -> int:
    with fitz.open(pdf_path) as doc:
        return doc.page_count


def remap_title(role: str, stage: str, level: int, title: str) -> str | None:
    if role == "en" and level == 1 and title == "封面":
        return None
    if role == "zh" and stage != "final" and level == 1 and title == "致谢":
        return None
    return title


def append_role_outline(
    outline_entries: list[tuple[int, str, int]],
    spec: RoleSpec,
    stage: str,
    pdf_path: Path,
    page_offset: int,
) -> None:
    if spec.include_source_outline:
        for level, title, source_page in extract_outline(pdf_path):
            mapped = remap_title(spec.role, stage, level, title)
            if not mapped:
                continue
            outline_entries.append((level, mapped, page_offset + source_page - 1))
        return

    if spec.label is not None:
        outline_entries.append((1, spec.label, page_offset))


def add_outline(writer: PdfWriter, outline_entries: list[tuple[int, str, int]]) -> None:
    parents: dict[int, object] = {}
    for level, title, page_index in outline_entries:
        parent = parents.get(level - 1)
        item = writer.add_outline_item(title, page_index, parent=parent)
        parents[level] = item
        for existing_level in list(parents.keys()):
            if existing_level > level:
                del parents[existing_level]


def merge_pdfs(stage: str, output_path: Path, input_paths: list[Path]) -> None:
    specs = STAGE_ROLE_SPECS[stage]
    if len(input_paths) != len(specs):
        raise ValueError(
            f"Stage '{stage}' expects {len(specs)} PDFs, got {len(input_paths)}."
        )

    writer = PdfWriter()
    writer.page_mode = "/UseOutlines"
    outline_entries: list[tuple[int, str, int]] = []
    current_page_offset = 0

    for spec, pdf_path in zip(specs, input_paths):
        if not pdf_path.exists():
            raise FileNotFoundError(f"Input PDF not found: {pdf_path}")
        append_role_outline(outline_entries, spec, stage, pdf_path, current_page_offset)
        writer.append(str(pdf_path), import_outline=False)
        current_page_offset += get_page_count(pdf_path)

    add_outline(writer, outline_entries)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("wb") as handle:
        writer.write(handle)


def main() -> None:
    args = parse_args()
    output_path = Path(args.output)
    input_paths = [Path(path) for path in args.inputs]
    merge_pdfs(args.stage, output_path, input_paths)


if __name__ == "__main__":
    main()
