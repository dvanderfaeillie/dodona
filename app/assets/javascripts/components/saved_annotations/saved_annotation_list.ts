import { customElement, property } from "lit/decorators.js";
import { html, TemplateResult } from "lit";
import { ShadowlessLitElement } from "components/shadowless_lit_element";
import { getSavedAnnotations, SavedAnnotation } from "state/SavedAnnotations";
import { stateMixin } from "state/StateMixin";
import "./edit_saved_annotation";

@customElement("d-saved-annotation-list")
export class SavedAnnotationList extends stateMixin(ShadowlessLitElement) {
    @property({ type: Number, attribute: "course-id" })
    courseId: number;
    @property({ type: Number, attribute: "exercise-id" })
    exerciseId: number;
    @property({ type: Number, attribute: "user-id" })
    userId: number;

    state = ["getSavedAnnotations"];

    get savedAnnotations(): SavedAnnotation[] {
        return getSavedAnnotations({
            "course_id": this.courseId.toString(),
            "exercise_id": this.exerciseId.toString(),
            "user_id": this.userId.toString()
        });
    }

    render(): TemplateResult {
        return this.savedAnnotations.length > 0 ? html`
            <div class="card-supporting-text card-border">
                <h4 class="ellipsis-overflow" title=">${I18n.t("js.saved_annotation.list.title")}">
                    ${I18n.t("js.saved_annotation.list.title")}
                </h4>
                <table class="table table-index table-resource">
                    <tbody>
                        ${this.savedAnnotations.map(sa => html`
                            <tr>
                                <td>${sa.title}</td>
                                <td class="actions">
                                    <d-edit-saved-annotation .savedAnnotation=${sa}></d-edit-saved-annotation>
                                    <a class="btn btn-icon btn-icon-filled bg-danger">
                                        <i class="mdi mdi-delete"></i>
                                    </a>
                                </td>
                            </tr>
                        `)}
                    </tbody>
                </table>
            </div>
        ` : html``;
    }
}
