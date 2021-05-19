# frozen_string_literal: true

module Bundler
  class SourceMap
    attr_reader :sources, :dependencies

    def initialize(sources, dependencies)
      @sources = sources
      @dependencies = dependencies
    end

    def pinned_spec_names(skip = nil)
      direct_requirements.reject {|_, source| source == skip }.keys
    end

    def all_requirements
      no_ambiguous_sources = Bundler.feature_flag.bundler_3_mode?
      requirements = direct_requirements.dup

      sources.non_default_sources.each do |source|
        loop do
          requirement_count = requirements.size
          new_names = source.dependency_names_to_double_check

          unless new_names.nil?
            new_names.uniq!
            new_names -= pinned_spec_names(source) + source.unmet_deps

            new_names.each do |new_name|
              previous_source = requirements[new_name]
              if previous_source.nil?
                requirements[new_name] = source
              elsif previous_source == source
                next
              else
                msg = ["The gem '#{new_name}' was found in multiple relevant sources."]
                msg.concat [previous_source, source].map {|s| "  * #{s}" }.sort
                msg << "You #{no_ambiguous_sources ? :must : :should} add this gem to the source block for the source you wish it to be installed from."
                msg = msg.join("\n")

                raise SecurityError, msg if no_ambiguous_sources
                Bundler.ui.warn "Warning: #{msg}"
              end
            end
          end

          source.double_check_for(-> { new_names })

          break if requirement_count == requirements.size
        end
      end

      unmet_deps = sources.non_default_sources.map(&:unmet_deps).flatten.uniq - requirements.keys
      sources.default_source.double_check_for(-> { unmet_deps })

      requirements
    end

    def direct_requirements
      @direct_requirements ||= begin
        requirements = {}
        default = sources.default_source
        dependencies.each do |dep|
          dep_source = dep.source || default
          dep_source.dependency_names = Array(dep_source.dependency_names).push(dep.name).uniq
          requirements[dep.name] = dep_source
        end
        requirements
      end
    end
  end
end
