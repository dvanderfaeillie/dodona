import { customElement, property } from "lit/decorators.js";
import { html, TemplateResult } from "lit";
import { ShadowlessLitElement } from "components/shadowless_lit_element";
import { createSavedAnnotation, SavedAnnotation } from "state/SavedAnnotations";
import "./saved_annotation_form";
import { modalMixin } from "components/modal_mixin";

@customElement("d-new-saved-annotation")
export class NewSavedAnnotation extends modalMixin(ShadowlessLitElement) {
    @property({ type: Number, attribute: "from-annotation-id" })
    fromAnnotationId: number;
    @property({ type: String, attribute: "annotation-text" })
    annotationText: string;

    @property({ state: true })
    errors: string[];

    savedAnnotation: SavedAnnotation;

    get newSavedAnnotation(): SavedAnnotation {
        return {
            id: undefined,
            title: "",
            annotation_text: this.annotationText
        };
    }

    async createSavedAnnotation(): Promise<void> {
        try {
            await createSavedAnnotation({
                from: this.fromAnnotationId,
                saved_annotation: this.savedAnnotation
            });
            this.errors = undefined;
            this.hideModal();
        } catch (errors) {
            this.errors = errors;
        }
    }

    get filledModalTemplate(): TemplateResult {
        return this.modalTemplate(html`
            ${I18n.t("js.saved_annotation.new.title")}
        `, html`
            ${this.errors !== undefined ? html`
                <div class="callout callout-danger">
                    <h4>${I18n.t("js.saved_annotation.new.errors", {count: this.errors.length})}</h4>
                    <ul>
                        ${this.errors.map(error => html`
                            <li>${error}</li>`)}
                    </ul>
                </div>
            ` : ""}
            <d-saved-annotation-form
                .savedAnnotation=${this.newSavedAnnotation}
                @change=${e => this.savedAnnotation = e.detail}
            ></d-saved-annotation-form>
        `, html`
            <button class="btn btn-primary btn-text" @click=${() => this.createSavedAnnotation()}>
                ${I18n.t("js.saved_annotation.new.save")}
            </button>
        `);
    }

    render(): TemplateResult {
        return html`
            <a class="btn btn-icon annotation-control-button annotation-edit"
               title="${I18n.t("js.saved_annotation.new.button_title")}"
               @click=${() => this.showModal()}
            >
                <i class="mdi mdi-content-save"></i>
            </a>`;
    }
}
