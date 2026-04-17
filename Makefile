# ============================================================
# PHBS 硕士学位论文 LaTeX 模板 - Makefile
# ============================================================
#
# 用户入口保持不变:
#   make blind
#   make defense
#   make final
#   make / make all
#
# 内部规则:
#   - blind / defense / final 单独调用时，总是重新编译该阶段
#   - all 只在当前调用内部复用唯一分册变体
#   - stage 通过工作目录里的 stage.auto.tex 自动传递，不改写 configs.tex
#
# ============================================================

# 目录定义
PARTS_DIR := parts
COVER_DIR := $(PARTS_DIR)/cover
EN_DIR := $(PARTS_DIR)/en
ZH_DIR := $(PARTS_DIR)/zh
SHARED_DIR := shared
PDF_DIR := pdf
OUTPUT_DIR := output
BUILD_DIR := $(OUTPUT_DIR)/.build
ALL_BUILD_DIR := $(BUILD_DIR)/all
SINGLE_BUILD_DIR := $(BUILD_DIR)/single
PREVIEW_BUILD_DIR := $(BUILD_DIR)/preview

COPYRIGHT_PDF ?= $(PDF_DIR)/copyright.pdf
ORIGINALITY_PDF ?= $(PDF_DIR)/originauth.pdf
COMMITMENT_PDF ?= $(PDF_DIR)/commitment.pdf
BACK_COVER_PDF ?= $(PDF_DIR)/back-cover.pdf

# 编译工具配置
XELATEX := xelatex
XELATEX_FLAGS := -synctex=1 -interaction=nonstopmode -file-line-error
BIBER := biber

# latexmk 配置 (用于 watch 模式)
LATEXMK := latexmk
LATEXMK_FLAGS := -xelatex -synctex=1 -interaction=nonstopmode -file-line-error
POWERSHELL := powershell -NoProfile -ExecutionPolicy Bypass -Command
PYTHON := python

# authored shared source；parts/* 与 output/.build 里看到的同名文件都视为镜像
SHARED_FILES := pkuthss.cls pkuthss-utf8.def miscs.tex template_text_utils.tex template_layout_policy.tex template_stage_policy.tex
SHARED_DIRS := img

ALL_VARIANT_PDFS := \
	$(ALL_BUILD_DIR)/cover-blind/main.pdf \
	$(ALL_BUILD_DIR)/cover-defense/main.pdf \
	$(ALL_BUILD_DIR)/cover-final/main.pdf \
	$(ALL_BUILD_DIR)/en-blind/main.pdf \
	$(ALL_BUILD_DIR)/en-defense/main.pdf \
	$(ALL_BUILD_DIR)/en-final/main.pdf \
	$(ALL_BUILD_DIR)/zh-nonfinal/main.pdf \
	$(ALL_BUILD_DIR)/zh-final/main.pdf

.PHONY: all blind defense final cover en zh watch-zh watch-en clean cleanall zip help check-official-assets sync-public-mirrors sync-preview-parts FORCE

FORCE:

stage_for_zh = $(if $(filter final,$1),final,defense)

define prepare_part_workdir
	@rm -rf "$(1)"
	@mkdir -p "$(1)"
	@cp -Rf "$(2)/." "$(1)/"
	@cp -f "configs.tex" "$(1)/configs.tex"
	@for f in $(SHARED_FILES); do \
		cp -f "$(SHARED_DIR)/$$f" "$(1)/"; \
	done
	@for d in $(SHARED_DIRS); do \
		cp -Rf "$(SHARED_DIR)/$$d" "$(1)/"; \
	done
	@printf '%s\n' '\\renewcommand{\\stage}{$(3)}' > "$(1)/stage.auto.tex"
endef

define compile_cover_pdf
	@cd "$(1)" && $(XELATEX) $(XELATEX_FLAGS) main.tex >/dev/null 2>&1
	@cd "$(1)" && $(XELATEX) $(XELATEX_FLAGS) main.tex >/dev/null 2>&1
endef

define compile_body_pdf
	@cd "$(1)" && $(XELATEX) $(XELATEX_FLAGS) main.tex >/dev/null 2>&1
	@cd "$(1)" && $(BIBER) main >/dev/null 2>&1
	@cd "$(1)" && $(XELATEX) $(XELATEX_FLAGS) main.tex >/dev/null 2>&1
	@cd "$(1)" && $(XELATEX) $(XELATEX_FLAGS) main.tex >/dev/null 2>&1
endef

define assemble_stage
	@rm -rf "$(OUTPUT_DIR)/$(1)"
	@mkdir -p "$(OUTPUT_DIR)/$(1)"
	@cp -f "$(2)" "$(OUTPUT_DIR)/$(1)/01-cover.pdf"
	@if [ "$(1)" = "final" ]; then \
		$(POWERSHELL) "Copy-Item -LiteralPath '$(COPYRIGHT_PDF)' -Destination '$(OUTPUT_DIR)/$(1)/02-copyright.pdf' -Force"; \
		cp -f "$(3)" "$(OUTPUT_DIR)/$(1)/03-en.pdf"; \
		cp -f "$(4)" "$(OUTPUT_DIR)/$(1)/04-zh.pdf"; \
		$(POWERSHELL) "Copy-Item -LiteralPath '$(COMMITMENT_PDF)' -Destination '$(OUTPUT_DIR)/$(1)/05-commitment.pdf' -Force"; \
		$(POWERSHELL) "Copy-Item -LiteralPath '$(ORIGINALITY_PDF)' -Destination '$(OUTPUT_DIR)/$(1)/06-originauth.pdf' -Force"; \
		$(POWERSHELL) "Copy-Item -LiteralPath '$(BACK_COVER_PDF)' -Destination '$(OUTPUT_DIR)/$(1)/07-back-cover.pdf' -Force"; \
		$(PYTHON) scripts/merge_pdfs.py --stage $(1) \
			$(OUTPUT_DIR)/$(1)/thesis.pdf \
			$(OUTPUT_DIR)/$(1)/01-cover.pdf \
			$(OUTPUT_DIR)/$(1)/02-copyright.pdf \
			$(OUTPUT_DIR)/$(1)/03-en.pdf \
			$(OUTPUT_DIR)/$(1)/04-zh.pdf \
			$(OUTPUT_DIR)/$(1)/05-commitment.pdf \
			$(OUTPUT_DIR)/$(1)/06-originauth.pdf \
			$(OUTPUT_DIR)/$(1)/07-back-cover.pdf; \
	else \
		cp -f "$(3)" "$(OUTPUT_DIR)/$(1)/02-en.pdf"; \
		cp -f "$(4)" "$(OUTPUT_DIR)/$(1)/03-zh.pdf"; \
		$(PYTHON) scripts/merge_pdfs.py --stage $(1) \
			$(OUTPUT_DIR)/$(1)/thesis.pdf \
			$(OUTPUT_DIR)/$(1)/01-cover.pdf \
			$(OUTPUT_DIR)/$(1)/02-en.pdf \
			$(OUTPUT_DIR)/$(1)/03-zh.pdf; \
	fi
endef

# ============================================================
# 自动工作目录编译规则
# ============================================================

$(ALL_BUILD_DIR)/cover-%/main.pdf: FORCE
	@echo "  [all] 编译封面变体 $*..."
	$(call prepare_part_workdir,$(@D),$(COVER_DIR),$*)
	$(call compile_cover_pdf,$(@D))

$(ALL_BUILD_DIR)/en-%/main.pdf: FORCE
	@echo "  [all] 编译英文分册 $*..."
	$(call prepare_part_workdir,$(@D),$(EN_DIR),$*)
	$(call compile_body_pdf,$(@D))

$(ALL_BUILD_DIR)/zh-%/main.pdf: FORCE
	@echo "  [all] 编译中文分册 $*..."
	$(call prepare_part_workdir,$(@D),$(ZH_DIR),$(call stage_for_zh,$*))
	$(call compile_body_pdf,$(@D))

$(SINGLE_BUILD_DIR)/%/cover/main.pdf: FORCE
	@echo "  [single] 编译封面分册 $*..."
	$(call prepare_part_workdir,$(@D),$(COVER_DIR),$*)
	$(call compile_cover_pdf,$(@D))

$(SINGLE_BUILD_DIR)/%/en/main.pdf: FORCE
	@echo "  [single] 编译英文分册 $*..."
	$(call prepare_part_workdir,$(@D),$(EN_DIR),$*)
	$(call compile_body_pdf,$(@D))

$(SINGLE_BUILD_DIR)/%/zh/main.pdf: FORCE
	@echo "  [single] 编译中文分册 $*..."
	$(call prepare_part_workdir,$(@D),$(ZH_DIR),$(call stage_for_zh,$*))
	$(call compile_body_pdf,$(@D))

$(PREVIEW_BUILD_DIR)/cover-final/main.pdf: FORCE
	@echo "  [preview] 编译封面..."
	$(call prepare_part_workdir,$(@D),$(COVER_DIR),final)
	$(call compile_cover_pdf,$(@D))

$(PREVIEW_BUILD_DIR)/en-final/main.pdf: FORCE
	@echo "  [preview] 编译英文分册..."
	$(call prepare_part_workdir,$(@D),$(EN_DIR),final)
	$(call compile_body_pdf,$(@D))

$(PREVIEW_BUILD_DIR)/zh-final/main.pdf: FORCE
	@echo "  [preview] 编译中文分册..."
	$(call prepare_part_workdir,$(@D),$(ZH_DIR),final)
	$(call compile_body_pdf,$(@D))

# ============================================================
# 默认目标: 编译所有三个版本（仅本次调用内部复用）
# ============================================================

all: check-official-assets $(ALL_VARIANT_PDFS)
	@echo ""
	@echo "============================================================"
	@echo "  组装全部阶段成品"
	@echo "============================================================"
	$(call assemble_stage,blind,$(ALL_BUILD_DIR)/cover-blind/main.pdf,$(ALL_BUILD_DIR)/en-blind/main.pdf,$(ALL_BUILD_DIR)/zh-nonfinal/main.pdf)
	$(call assemble_stage,defense,$(ALL_BUILD_DIR)/cover-defense/main.pdf,$(ALL_BUILD_DIR)/en-defense/main.pdf,$(ALL_BUILD_DIR)/zh-nonfinal/main.pdf)
	$(call assemble_stage,final,$(ALL_BUILD_DIR)/cover-final/main.pdf,$(ALL_BUILD_DIR)/en-final/main.pdf,$(ALL_BUILD_DIR)/zh-final/main.pdf)
	@echo ""
	@echo "============================================================"
	@echo "  全部编译完成!"
	@echo "============================================================"
	@echo ""
	@echo "  输出文件:"
	@echo "    $(OUTPUT_DIR)/blind/thesis.pdf    <- 盲审版 (送审用)"
	@echo "    $(OUTPUT_DIR)/defense/thesis.pdf  <- 答辩版 (答辩用)"
	@echo "    $(OUTPUT_DIR)/final/thesis.pdf    <- 最终版 (存档用)"
	@echo ""

# ============================================================
# 三个阶段的编译目标（单独调用时总是重编）
# ============================================================

blind: $(SINGLE_BUILD_DIR)/blind/cover/main.pdf $(SINGLE_BUILD_DIR)/blind/en/main.pdf $(SINGLE_BUILD_DIR)/blind/zh/main.pdf
	@echo ""
	@echo "============================================================"
	@echo "  组装盲审版 (blind)"
	@echo "  - 隐藏: 学生姓名、学号、导师信息"
	@echo "  - 不含: 致谢、原创性声明"
	@echo "============================================================"
	$(call assemble_stage,blind,$(SINGLE_BUILD_DIR)/blind/cover/main.pdf,$(SINGLE_BUILD_DIR)/blind/en/main.pdf,$(SINGLE_BUILD_DIR)/blind/zh/main.pdf)
	@echo "  -> $(OUTPUT_DIR)/blind/thesis.pdf"

defense: $(SINGLE_BUILD_DIR)/defense/cover/main.pdf $(SINGLE_BUILD_DIR)/defense/en/main.pdf $(SINGLE_BUILD_DIR)/defense/zh/main.pdf
	@echo ""
	@echo "============================================================"
	@echo "  组装答辩版 (defense)"
	@echo "  - 显示: 学生姓名、学号"
	@echo "  - 隐藏: 导师信息"
	@echo "  - 不含: 致谢、原创性声明"
	@echo "============================================================"
	$(call assemble_stage,defense,$(SINGLE_BUILD_DIR)/defense/cover/main.pdf,$(SINGLE_BUILD_DIR)/defense/en/main.pdf,$(SINGLE_BUILD_DIR)/defense/zh/main.pdf)
	@echo "  -> $(OUTPUT_DIR)/defense/thesis.pdf"

final: check-official-assets $(SINGLE_BUILD_DIR)/final/cover/main.pdf $(SINGLE_BUILD_DIR)/final/en/main.pdf $(SINGLE_BUILD_DIR)/final/zh/main.pdf
	@echo ""
	@echo "============================================================"
	@echo "  组装最终版 (final)"
	@echo "  - 显示: 所有信息"
	@echo "  - 包含: 致谢、版权页、承诺书、原创性声明、封底"
	@echo "============================================================"
	$(call assemble_stage,final,$(SINGLE_BUILD_DIR)/final/cover/main.pdf,$(SINGLE_BUILD_DIR)/final/en/main.pdf,$(SINGLE_BUILD_DIR)/final/zh/main.pdf)
	@echo "  -> $(OUTPUT_DIR)/final/thesis.pdf"

# ============================================================
# 官方页检查
# ============================================================

check-official-assets:
	@$(POWERSHELL) "if (-not (Test-Path -LiteralPath '$(COPYRIGHT_PDF)')) { Write-Host '错误: 缺少官方版权声明 PDF：$(COPYRIGHT_PDF)'; exit 1 }"
	@$(POWERSHELL) "if (-not (Test-Path -LiteralPath '$(COMMITMENT_PDF)')) { Write-Host '错误: 缺少终版学位论文承诺书 PDF：$(COMMITMENT_PDF)'; exit 1 }"
	@$(POWERSHELL) "if (-not (Test-Path -LiteralPath '$(ORIGINALITY_PDF)')) { Write-Host '错误: 缺少原创性声明和授权使用说明 PDF：$(ORIGINALITY_PDF)'; exit 1 }"
	@$(POWERSHELL) "if (-not (Test-Path -LiteralPath '$(BACK_COVER_PDF)')) { Write-Host '错误: 缺少封底 PDF：$(BACK_COVER_PDF)'; exit 1 }"

# ============================================================
# 快捷命令 - 只编译某一部分 (调试用)
# ============================================================

cover: $(PREVIEW_BUILD_DIR)/cover-final/main.pdf
	@mkdir -p $(OUTPUT_DIR)
	@cp -f $(PREVIEW_BUILD_DIR)/cover-final/main.pdf $(OUTPUT_DIR)/cover.pdf
	@echo "==> 完成: $(OUTPUT_DIR)/cover.pdf"

en: $(PREVIEW_BUILD_DIR)/en-final/main.pdf
	@mkdir -p $(OUTPUT_DIR)
	@cp -f $(PREVIEW_BUILD_DIR)/en-final/main.pdf $(OUTPUT_DIR)/en.pdf
	@echo "==> 完成: $(OUTPUT_DIR)/en.pdf"

zh: $(PREVIEW_BUILD_DIR)/zh-final/main.pdf
	@mkdir -p $(OUTPUT_DIR)
	@cp -f $(PREVIEW_BUILD_DIR)/zh-final/main.pdf $(OUTPUT_DIR)/zh.pdf
	@echo "==> 完成: $(OUTPUT_DIR)/zh.pdf"

# ============================================================
# 监视模式 - 写作时自动编译
# ============================================================

sync-public-mirrors:
	@echo "==> 同步 public authored source 到 parts 镜像..."
	@for dir in $(COVER_DIR) $(EN_DIR) $(ZH_DIR); do \
		cp -f configs.tex "$$dir/configs.tex"; \
		for f in $(SHARED_FILES); do \
			cp -f "$(SHARED_DIR)/$$f" "$$dir/"; \
		done; \
		for d in $(SHARED_DIRS); do \
			cp -Rf "$(SHARED_DIR)/$$d" "$$dir/"; \
		done; \
	done

sync-preview-parts: sync-public-mirrors
	@echo "==> 写入 final 预览阶段到 parts 镜像..."
	@for dir in $(COVER_DIR) $(EN_DIR) $(ZH_DIR); do \
		printf '%s\n' '\\renewcommand{\\stage}{final}' > "$$dir/stage.auto.tex"; \
	done

watch-zh: sync-preview-parts
	@echo "==> 监视中文版，自动编译 (Ctrl+C 退出)..."
	@cd $(ZH_DIR) && $(LATEXMK) -pvc $(LATEXMK_FLAGS) main.tex

watch-en: sync-preview-parts
	@echo "==> 监视英文版，自动编译 (Ctrl+C 退出)..."
	@cd $(EN_DIR) && $(LATEXMK) -pvc $(LATEXMK_FLAGS) main.tex

# ============================================================
# 清理
# ============================================================

clean:
	@echo "==> 清理编译缓存..."
	@cd $(COVER_DIR) && $(LATEXMK) -c 2>/dev/null || true
	@cd $(EN_DIR) && $(LATEXMK) -c 2>/dev/null || true
	@cd $(ZH_DIR) && $(LATEXMK) -c 2>/dev/null || true
	@rm -rf $(BUILD_DIR)
	@echo "    完成"

cleanall: clean
	@echo "==> 清理所有生成文件..."
	@cd $(COVER_DIR) && $(LATEXMK) -C 2>/dev/null || true
	@cd $(EN_DIR) && $(LATEXMK) -C 2>/dev/null || true
	@cd $(ZH_DIR) && $(LATEXMK) -C 2>/dev/null || true
	@rm -rf $(OUTPUT_DIR)
	@rm -f $(COVER_DIR)/configs.tex $(EN_DIR)/configs.tex $(ZH_DIR)/configs.tex
	@rm -f $(COVER_DIR)/stage.auto.tex $(EN_DIR)/stage.auto.tex $(ZH_DIR)/stage.auto.tex
	@rm -f $(COVER_DIR)/miscs.tex $(EN_DIR)/miscs.tex $(ZH_DIR)/miscs.tex
	@rm -f $(COVER_DIR)/template_text_utils.tex $(EN_DIR)/template_text_utils.tex $(ZH_DIR)/template_text_utils.tex
	@rm -f $(COVER_DIR)/template_layout_policy.tex $(EN_DIR)/template_layout_policy.tex $(ZH_DIR)/template_layout_policy.tex
	@rm -f $(COVER_DIR)/template_stage_policy.tex $(EN_DIR)/template_stage_policy.tex $(ZH_DIR)/template_stage_policy.tex
	@rm -f $(COVER_DIR)/pkuthss.cls $(EN_DIR)/pkuthss.cls $(ZH_DIR)/pkuthss.cls
	@rm -f $(COVER_DIR)/pkuthss-utf8.def $(EN_DIR)/pkuthss-utf8.def $(ZH_DIR)/pkuthss-utf8.def
	@rm -rf $(COVER_DIR)/img $(EN_DIR)/img $(ZH_DIR)/img
	@echo "    完成"

# ============================================================
# 打包
# ============================================================

zip: cleanall
	@echo "==> 打包项目..."
	@zip -r thesis-template.zip . \
		-x "*.git*" \
		-x "*.DS_Store" \
		-x "*.zip" \
		-x "output/*"
	@echo "    已生成 thesis-template.zip"

# ============================================================
# 帮助
# ============================================================

help:
	@echo ""
	@echo "PHBS 硕士学位论文 LaTeX 模板"
	@echo "============================="
	@echo ""
	@echo "快速开始:"
	@echo "  1. 编辑 configs.tex 填写你的论文信息"
	@echo "  2. 把官方 PDF 放到 pdf/ 目录"
	@echo "  3. 在 parts/zh/chap/ 和 parts/en/chap/ 写论文"
	@echo "  4. 运行 make all 编译三个版本"
	@echo ""
	@echo "官方页默认文件名:"
	@echo "  $(COPYRIGHT_PDF)"
	@echo "  $(COMMITMENT_PDF)"
	@echo "  $(ORIGINALITY_PDF)"
	@echo "  $(BACK_COVER_PDF)"
	@echo ""
	@echo "常用命令:"
	@echo "  make          一键编译三个版本 (盲审/答辩/最终)"
	@echo "  make blind    只编译盲审版 (每次重新编译)"
	@echo "  make defense  只编译答辩版 (每次重新编译)"
	@echo "  make final    只编译最终版 (每次重新编译)"
	@echo ""
	@echo "写作时:"
	@echo "  make zh       只编译中文版 (快速预览)"
	@echo "  make en       只编译英文版"
	@echo "  make watch-zh 监视模式，保存时自动编译"
	@echo "  make sync-public-mirrors 同步 public authored source 到 parts 镜像"
	@echo ""
	@echo "说明:"
	@echo "  - blind / defense / final 单独调用时，总是重新编译"
	@echo "  - make all 只在当前调用内部复用唯一分册变体"
	@echo "  - configs.tex 中的默认 \\stage 只作为手工单独编译时的后备值"
	@echo ""
	@echo "其他:"
	@echo "  make clean    清理编译缓存"
	@echo "  make cleanall 清理所有生成文件"
	@echo "  make zip      打包模板"
	@echo "  make help     显示此帮助"
	@echo ""
	@echo "输出目录: $(OUTPUT_DIR)/"
	@echo "  blind/thesis.pdf    盲审版"
	@echo "  defense/thesis.pdf  答辩版"
	@echo "  final/thesis.pdf    最终版"
	@echo ""
