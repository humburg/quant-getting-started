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
require 'yaml'

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
      if( !@options.nil? )
        @options.each do |k, v|
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

  # Create speaker notes
  class Notes < Liquid::Block
    def render(context)
      slide_mode = false
      if( !context.registers[:page]['mode'].nil? && context.registers[:page]['mode'] == "slides" )
        slide_mode = true
      end

      output = ""
      if( slide_mode )
        output = "Notes:\n"
      end
      output += super
      return output
    end
  end

  # Generate slide markdown from posts
  class SlideGenerator < Jekyll::Generator
    safe true

    ## TODO go through list of options to identify all that should be removed for slides
    BLOG_OPTIONS = ['aside', 'sidebar'].freeze

    def generate(site)
      site.posts.docs.each do |post|
        if post.data['mode'] == 'both'
          # Extract relevant content from blog posts
          raw = File.read(post.path)
          parts = split_frontmatter(raw)
          frontmatter = YAML.load(parts[0])
          frontmatter = self.slide_frontmatter(frontmatter)
          frontmatter['description'] = post.data["excerpt"].to_s
          slide_content = self.extract_slides(parts[1])

          # Convert class tags
          slide_content.gsub!(/\{:\s*\.([^} ]+)\s*\}/, '<!-- .element: class="\\1" -->')

          # Add title slide
          title_slide = File.read('_includes/slides/title/title.md')
          slide_content = title_slide + slide_content

          # write new markdown file
          slides = File.open(self.slide_path(post), 'w')
          slides.puts(frontmatter.to_yaml)
          slides.puts("---\n")
          slides.puts(slide_content)
          slides.close

          # Add page to queue
          site.collections['slides'].docs << Page.new(site, site.source, '_slides', post.basename)
        end
      end
    end

    # split file into front matter and main content
    def split_frontmatter(raw_content)
      matches = raw_content.match(/^---\s*\r?\n(.*?)\r?\n^(---|\.\.\.)\r?\n(.*)/m)
      return [matches.captures[0], matches.captures[2]]
    end

    # modify frontmatter to ensure it is suitable for slides
    def slide_frontmatter(post_frontmatter)
      frontmatter = {}
      post_frontmatter.each do |k,v|
        if !BLOG_OPTIONS.include? k
          frontmatter[k] = v
        end
      end
      if frontmatter.key? 'layout'
        frontmatter['layout'] = 'slide'
      end
      frontmatter['mode'] = 'slides'
      return frontmatter
    end

    # extract slide content, remove blog only content
    def extract_slides(content)
      content.sub!(/\A.*?({%\s+slide\s.*?%})/m, "\\1")
      content.gsub!(/({%\s+endslide\s+%}).*?({%\s+slide\s+.*?%})/m, "\\1\n\\2")
      content.sub!(/(.*{%\s+endslide\s+%}\r?\n?).*?\z/m, "\\1")
      return content
    end

    def slide_path(post)
      return post.path.sub('_posts', '_slides')
    end
  end
end

Liquid::Template.register_tag("slide", Jekyll::Slide)
Liquid::Template.register_tag("notes", Jekyll::Notes)
