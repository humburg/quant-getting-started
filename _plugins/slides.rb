# Generating slides and blog posts from the same Markdown input
#
# Author: Peter Humburg
#
# Relies on reveal.js to create slides.
#
# New Liquid tags: {% slide %}, {% note %}
#       supported tag options:
#             - slideonly: suppress content in blog output
#             - reveal: Has of the form {"option":"value"} providing
#                       reveal data attributes.

require 'json'

module Jekyll
  class Slide < Liquid::Block
    def initialize(tag_name, options, tokens)
      super
      @input = options
      # set defaults
      @slideonly = false
      @options = {}
      # Parse tag options
      begin
        if( !@input.nil? && !@input.empty? )
          if( @input.include?("slideonly") )
            @slideonly = true
          end
          @input = @input[/.*({.*})/, 1]
          if( !input.nil? && @input != "{}" )
            @options = JSON.parse(@input)
          end
        end
      rescue
          @options = {}
      end
    end

    def slideonly?
      return @slideonly
    end

    # render options as data tags
    def render_options
      values = ""
      if( !self.options.nil? )
        self.options.each do |k, v|
          values << " data-#{k}='#{v}'"
        end
      end
      return values
    end

    def render(context)
      slide_mode = false
      if( !context.registers[:page]['mode'].nil? && context.registers[:page]['mode'] == "slides" )
        slide_mode = true
      end

      if( slide_mode )
        data_opt = self.render_options
        output = "<section data-markdown" + data_opt + ">\n"
        output += "<textarea data-template>\n" + super
        output += "</textarea>\n</section>"
      else
        if( self.slideonly? )
          output = ""
        else
          output = super
        end
      end
      return output
    end
  end
end

Liquid::Template.register_tag("slide", Jekyll::Slide)
