class FeedbackCodeRenderer
  include ApplicationHelper
  include Rails.application.routes.url_helpers
  require 'json'

  def initialize(code, user, programming_language, messages = nil, builder = nil)
    @code = code
    @programming_language = programming_language
    @messages = messages || []
    @user = user
    @builder = builder || Builder::XmlMarkup.new

    @compress = false
  end

  def add_submission(submission_id)
    @submission_id = submission_id
    @submission = Submission.find(@submission_id)
    @code = @submission.code
    @programming_language = @submission.exercise&.programming_language&.name
    @annotations = @submission.annotations
    self
  end

  def parse
    line_formatter = Rouge::Formatters::HTML.new
    table_formatter = Rouge::Formatters::HTMLLineTable.new line_formatter, table_class: 'code-listing highlighter-rouge'

    lexer = (Rouge::Lexer.find(@programming_language) || Rouge::Lexers::PlainText).new
    lexed_c = lexer.lex(@code.encode(universal_newline: true))

    only_errors = @messages.select { |message| message[:type] == :error || message[:type] == 'error' }
    @compress = !only_errors.empty? && only_errors.size != @messages.size

    @builder.div(class: 'feedback-table-options') do
      @builder.span(id: 'annotations-were-hidden', class: 'hide') do
      end
      @builder.span(class: 'flex-spacer') do
      end
      @builder.span(class: 'diff-switch-buttons switch-buttons') do
        @builder.span(id: 'diff-switch-prefix', class: 'hide') do
          @builder.text!(I18n.t('submissions.show.annotations.title'))
        end
        @builder.div(class: 'btn-group btn-toggle', role: 'group', 'aria-label': I18n.t('submissions.show.annotations.title'), 'data-toggle': 'buttons') do
          @builder.button(class: 'btn btn-secondary active hide', id: 'show_all_annotations', title: I18n.t('submissions.show.annotations.show_all'), 'data-toggle': 'tooltip', 'data-placement': 'top') do
            @builder.i(class: 'mdi mdi-18 mdi-comment-multiple-outline') {}
          end
          @builder.button(class: 'btn btn-secondary hide', id: 'show_only_errors', title: I18n.t('submissions.show.annotations.show_errors'), 'data-toggle': 'tooltip', 'data-placement': 'top') do
            @builder.i(class: 'mdi mdi-18 mdi-comment-alert-outline') {}
          end
          @builder.button(class: 'btn btn-secondary hide', id: 'hide_all_annotations', title: I18n.t('submissions.show.annotations.hide_all'), 'data-toggle': 'tooltip', 'data-placement': 'top') do
            @builder.i(class: 'mdi mdi-18 mdi-comment-remove-outline') {}
          end
        end
      end
    end

    @builder << table_formatter.format(lexed_c)
    self
  end

  def add_messages
    @builder.script(type: 'application/javascript') do
      @builder << "window.dodona.codeListing = new window.dodona.codeListingClass(#{@code.dump});"
      @builder << '$(() => window.dodona.codeListing.addAnnotations(' + @messages.map { |o| Hash[o.each_pair.to_a] }.to_json + '));'
      @builder << '$(() => window.dodona.codeListing.showAllAnnotations());'
      @builder << '$(() => window.dodona.codeListing.compressAnnotations());' if @compress
      if @submission
        @builder << "$(() => window.dodona.codeListing.addUserAnnotations('#{submission_annotations_path 'nl', @submission_id}'));"
        @builder << '$(() => window.dodona.codeListing.initButtonForComment());' if AnnotationPolicy.new(@user, @submission).show_comment_button?
      end
    end
  end

  def html
    @builder.html_safe
  end
end
