# Copyright (c) 2008 Robert Head
# Released under the MIT license.
#
# ActsAsDenormalized
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'active_record'

module ActiveRecord #:nodoc:
  module Acts #:nodoc:

    # Specify this act if you want to automatically calculate denormalized values on save.
    # Dependency: Ruby on Rails 2.1 or higher.
    #
    # Denormalizing data is a common strategy to help reduce database reads (especially joins).
    # See: http://en.wikipedia.org/wiki/Denormalization
    #
    # For example, in a forum, if I want to display the name of the author of each post,
    # I could store the author's name in the Post objects instead of fetching all the associated User records.
    # Storing the author's name in the Post is redundant (not normalized), but avoids loading the user record
    # just to read the name.
    #
    # Tradeoff:
    # At the cost of slower writes and some potential for stale data,
    # you get faster reads by avoiding loading models you would otherwise have needed.
    #
    module Denormalized

      def self.included(base) # :nodoc:
        base.extend ActiveSupport::Memoizable
        base.extend ActiveRecord::Acts::Denormalized::ClassMethods
      end

      module ClassMethods

        attr_accessor :denormalized_attribute_prefix, :denormalized_compute_method_prefix, :denormalized_attribute_timestamp_suffix, :denormalized_on_changes_to_attributes, :denormalized_attributes_invalid_when_nil

        # Specify this act if you want to automatically calculate fields indicated as denormalized values.
        #
        # Options:
        # +attribute_prefix+ - specifies the field name prefix that indicates a denormalized field. (default = "denormalized_")  For example: :attribute_prefix => 'fast_'
        # +compute_prefix+ - specifies the method name prefix that calculates the denormalized value for a field. (default = "compute_denormalized_")  For example, :compute_prefix => 'compute_fast_'
        # +on_changes_to_attributes+ (optional) - specifies a hash of denormalized fields and the corresponding array of attributes whose changes trigger a recalculation of the denormalized value.  If a denormalized field is not listed as a key in this hash, by default it is recalculated via a before_save method whenever changed? is true.  An example... :on_changes_to_attributes => {:user_name => [:user]}
        #
        # Example:
        #
        # class Post
        #
        #   belongs_to :author, :class_name => 'User'
        #   has_many :comments
        #
        #   acts_as_denormalized(
        #     :on_changes_to_attributes => {
        #       :denormalized_author_name => [:author],
        #       :denormalized_comment_count => [:comments],
        #     }
        #   )
        #
        #   def compute_denormalized_author_name
        #     self.author.name
        #   end
        #
        #   def compute_denormalized_comment_count
        #     self.comments.size
        #   end
        #
        # end
        #
        def acts_as_denormalized(options = {})
          self.denormalized_attribute_prefix = (options[:attribute_prefix] || "denormalized_").to_s
          self.denormalized_compute_method_prefix = (options[:compute_prefix] || "compute_#{self.denormalized_attribute_prefix}").to_s
          self.denormalized_on_changes_to_attributes = options[:on_changes_to_attributes] || {}
          self.denormalized_attributes_invalid_when_nil = [options[:denormalized_attributes_invalid_when_nil]].flatten || []
          self.denormalized_attribute_timestamp_suffix = (options[:attribute_timestamp_suffix] || "_computed_at").to_s
          send( :include, InstanceMethods ) unless self.included_modules.include?(ActiveRecord::Acts::Denormalized::InstanceMethods)

          if false # options[:lazy_computation]
            before_save :unset_stale_denormalized_values
          else
            before_save :compute_denormalized_values
          end
          after_save :clear_computed_denormalized_attribute_names

          named_scope :with_unset_denormalized_values, :conditions => self.with_unset_denormalized_values_conditions
          named_scope :limit, lambda { |arg| { :limit => arg } }
          named_scope :recent_first, :order => "updated_at DESC"
          create_smart_attribute_methods
        end

        def with_unset_denormalized_values_conditions
          if denormalization_timestamps.empty?
            "0"
          else
            denormalization_timestamps.collect { |timestamp|
              "#{timestamp} IS NULL"
            }.join(" OR ")
          end
        end

        def acts_as_denormalized?
          self.included_modules.include?(ActiveRecord::Acts::Denormalized::InstanceMethods)
        end

        # Returns an array of the names of all denormalized attributes.
        def denormalized_attribute_names
          @denormalized_attribute_names ||= (self.column_names.select { |attribute_name| self.denormalized_attribute?(attribute_name) } rescue [])
        end

        # Returns an array of the names of all denormalized attribute computed_at timestamps.
        def denormalization_timestamps
          @denormalization_timestamps ||= (self.column_names.select { |attribute_name| self.denormalization_timestamp?(attribute_name) } rescue [])
        end

        # Returns the root of a denormalized attribute name.
        # For example, Post#denormalized_attribute_base_name(:denormalized_user_name) would return "user_name"
        def denormalized_attribute_base_name(attribute_name)
          attribute_name.to_s.sub(/^#{denormalized_attribute_prefix}/, '')
        end

        # Returns the method name that will be called to calculated the value of the attribute before saving.
        def denormalized_compute_method_name(attribute_name)
          denormalized_compute_method_prefix + denormalized_attribute_base_name(attribute_name)
        end

        def denormalized_attribute_name_from_base_name(base_name)
          denormalized_attribute_prefix + base_name.to_s
        end

        # Returns a value evaluating to true if attribute_name is a denormalized attribute.
        def denormalized_attribute?(attribute_name)
          attribute_name = attribute_name.to_s
          (column_names.include?(attribute_name) && !denormalization_timestamp?(attribute_name) && attribute_name =~ /^#{denormalized_attribute_prefix}.+$/) rescue false
        end

        def denormalization_timestamp?(attribute_name)
          attribute_name = attribute_name.to_s
          column_names.include?(attribute_name) && attribute_name =~ /^#{denormalized_attribute_prefix}.+#{denormalized_attribute_timestamp_suffix}$/ rescue false
        end

        def corresponding_denormalization_timestamp?(attribute_name)
          corresponding_denormalization_timestamp(attribute_name).present?
        end

        def corresponding_denormalization_timestamp(attribute_name)
          @corresponding_denormalization_timestamp ||= {}
          unless @corresponding_denormalization_timestamp[attribute_name]
            candidate = "#{attribute_name}#{denormalized_attribute_timestamp_suffix}"
            if (denormalized_attribute?(attribute_name) && self.column_names.include?(candidate) rescue false)
              @corresponding_denormalization_timestamp[attribute_name] = candidate
            end
          end
          @corresponding_denormalization_timestamp[attribute_name]
        end

        # Accepts the name of an attribute as a String of a Symbol
        #   and returns an array of the names of attributes
        #   that trigger recalculation when changed.
        def denormalized_attribute_triggers(attribute_name)
          triggers = (
            self.denormalized_on_changes_to_attributes[attribute_name.to_s] ||
            self.denormalized_on_changes_to_attributes[attribute_name.to_sym] ||
            []
          )
          triggers = [triggers].flatten.collect(&:to_s)
          # add foreign_key attributes, if necessary, for any belongs_to triggers
          additional_belongs_to_triggers = []
          triggers.each do |trigger|
            if self.reflect_on_all_associations(:belongs_to).collect(&:name).collect(&:to_s).include?(trigger)
              additional_belongs_to_triggers << "#{trigger}_id"
            end
          end
          triggers += additional_belongs_to_triggers
          triggers.compact.uniq
        end

        # accepts an attribute and unsets all instances of this class that meet the conditions
        def unset_denormalized_value_for_all(attribute_name, conditions = "1")
          unset_denormalized_values_for_all(attribute_name, conditions)
        end

        # accepts an attribute or list of attributes and unsets the value for all instances of this class that meet the conditions
        def unset_denormalized_values_for_all(attribute_names, conditions = "1")
          # clean up array of attribute names
          attribute_names = [attribute_names].flatten.compact.uniq.collect(&:to_s)
          # add corresponding timestamps
          attribute_names_to_unset = attribute_names +
            attribute_names.collect { |attribute_name| self.corresponding_denormalization_timestamp(attribute_name) }.compact
          # filter out bad attribute names
          attribute_names_to_unset &= self.column_names
          # do the update
          if attribute_names_to_unset.present? # check to see if any are left before making the update call
            updates = attribute_names_to_unset.collect {|attribute_name| "#{attribute_name} = NULL"}.join(", ")
            self.update_all(updates, conditions)
          end
        end

        def compute_all_unset_denormalized_attributes(limit = nil)
          self.with_unset_denormalized_values.limit(limit).each(&:compute_denormalized_values_by_sql)
        end

        # replacement for the method_missing magic
        def create_smart_attribute_methods
          denormalized_attribute_names.each do |denormalized_attribute_name|
            base_method_name = denormalized_attribute_base_name(denormalized_attribute_name)
            define_method(base_method_name) do
              if may_use_denormalized_value?(denormalized_attribute_name)
                self.send(denormalized_attribute_name)
              else
                self.send(self.class.denormalized_compute_method_name(denormalized_attribute_name))
              end
            end
          end
        end

      end

      module InstanceMethods

        def acts_as_denormalized?
          true
        end

        def unset_denormalized_value(attribute_name)
          self.send("#{attribute_name}=", nil)
          stamp = self.class.corresponding_denormalization_timestamp(attribute_name)
          if stamp.present?
            self.send("#{stamp}=", nil)
          end
          @computed_denormalized_attribute_names ||= []
          @computed_denormalized_attribute_names -= [attribute_name]
        end

        def unset_denormalized_values(attribute_names = [])
          attribute_names = [attribute_names].flatten.compact
          attribute_names = self.class.denormalized_attribute_names if attribute_names.blank?
          for attribute_name in attribute_names
            unset_denormalized_value(attribute_name)
          end
        end

        def unset_all_denormalized_values
          unset_denormalized_values
        end

        def recompute_denormalized_values
          unset_denormalized_values
          compute_denormalized_values_by_sql
        end

        def unset_stale_denormalized_values
          unset_denormalized_values(stale_denormalized_values)
        end

        def stale_denormalized_values
          self.class.denormalized_attribute_names.select { |attribute_name| denormalized_value_stale?(attribute_name) }
        end

        def unset_denormalized_value_by_sql(attribute_name)
          unset_denormalized_values_by_sql(attribute_name)
        end

        def unset_denormalized_values_by_sql(attribute_name)
          self.class.unset_denormalized_values_for_all(attribute_name, {:id => self.id})
          @computed_denormalized_attribute_names ||= []
          @computed_denormalized_attribute_names -= [attribute_name]
        end

        def unset_all_denormalized_values_by_sql
          unset_denormalized_values_by_sql(self.class.denormalized_attribute_names)
        end

        def denormalized_value_unset?(attribute_name)
          stamp = self.class.corresponding_denormalization_timestamp(attribute_name)
          stamp && self.send(stamp).nil?
        end

        def denormalized_values_unset
          self.class.denormalized_attribute_names.select { |attribute_name| denormalized_value_unset?(attribute_name) }
        end

        def denormalized_values_unset?
          self.class.denormalized_attribute_names.detect { |attribute_name| denormalized_value_unset?(attribute_name) }.present?
        end

        def compute_denormalized_value_by_sql(attribute_name)
          compute_denormalized_values_by_sql([attribute_name])
        end

        def compute_denormalized_values_by_sql(attribute_names = self.class.denormalized_attribute_names)
          unless self.new_record?
            attribute_updates = {}
            now = Time.zone.now
            attribute_names.each do |attribute_name|
              if denormalized_value_unset?(attribute_name) || denormalized_value_stale?(attribute_name)
                if !self.respond_to?(self.class.denormalized_compute_method_name(attribute_name))
                  raise "Could not find method #{self.class.denormalized_compute_method_name(attribute_name)} in class #{self.class.name}"
                else
                  attribute_updates[attribute_name] = self.send(self.class.denormalized_compute_method_name(attribute_name))
                  self[attribute_name] = attribute_updates[attribute_name]
                  stamp = self.class.corresponding_denormalization_timestamp(attribute_name)
                  if stamp.present?
                    attribute_updates[stamp] = now
                    self[stamp] = now
                  end
                end
              end
            end
            # account for serialized attributes
            for key in attribute_updates.keys
              if (self.class.serialized_attributes.keys.include?(key.to_s) rescue false)
                attribute_updates[key] = attribute_updates[key].to_yaml
              end
            end
            # save all updates
            self.class.update_all(attribute_updates, "id = #{self.id}") if attribute_updates.present?
          end
        end

        # This before_save callback recalculates the values of denormalized attributes as needed.
        def compute_denormalized_values(force_all = false)
          self.class.denormalized_attribute_names.each do |attribute_name|
            if force_all || denormalized_value_unset?(attribute_name) || denormalized_value_stale?(attribute_name)
              if !self.respond_to?(self.class.denormalized_compute_method_name(attribute_name))
                raise "Could not find method #{self.class.denormalized_compute_method_name(attribute_name)} in class #{self.class.name}"
              else
                compute_denormalized_value(attribute_name)
              end
            end
          end
        end

        def clear_computed_denormalized_attribute_names
          @computed_denormalized_attribute_names = []
        end

        def compute_denormalized_value(attribute_name)
          @computed_denormalized_attribute_names ||= []
          attribute_name = attribute_name.to_s
          unless @computed_denormalized_attribute_names.include?(attribute_name)
            if self.class.denormalized_attribute?(attribute_name)
              self.send("#{attribute_name}=", self.send(self.class.denormalized_compute_method_name(attribute_name)))
              stamp = self.class.corresponding_denormalization_timestamp(attribute_name)
              if stamp
                self.send("#{stamp}=", Time.zone.now)
              end
              @computed_denormalized_attribute_names << attribute_name
            end
          end
        end

        def denormalized_value_stale_by_field?(attribute_name)
          return false unless self.class.denormalized_attribute?(attribute_name)
          triggers = self.class.denormalized_attribute_triggers(attribute_name)
          return true if ['always', :always, ['always'], [:always]].include?(triggers)
          # an empty set of triggers means "any field"
          return self.changed? if triggers.blank?
          # return true if any of the trigger attributes have changed
          (triggers & self.changes.keys).present?
        end

        def denormalized_value_stale_by_association?(attribute_name)
          return false unless self.class.denormalized_attribute?(attribute_name)
          triggers = self.class.denormalized_attribute_triggers(attribute_name)
          return true if ['always', :always, ['always'], [:always]].include?(triggers)
          return false if triggers.blank?
          # cycle through more carefully to see if any associated objects have changed
          belongs_to_association_names = self.class.reflect_on_all_associations(:belongs_to).collect(&:name).collect(&:to_s)
          has_many_association_names = self.class.reflect_on_all_associations(:has_many).collect(&:name).collect(&:to_s)
          triggers.each do |trigger|
            if belongs_to_association_names.include?(trigger)
              trigger_object = self.send(trigger)
              if ( trigger_object && (
                trigger_object.changed? ||
                trigger_object.updated_at.nil? || self.updated_at.nil? ||
                trigger_object.updated_at > self.updated_at
                ) )
                return true
              end
            elsif has_many_association_names.include?(trigger)
              self.send(trigger).each do |has_many_element|
                if (
                  has_many_element.new_record? ||
                  has_many_element.changed? ||
                  has_many_element.updated_at.nil? ||
                  self.updated_at.nil? ||
                  has_many_element.updated_at > self.updated_at
                  )
                  return true
                end
              end
            end
          end
          false
        end

        # Returns true if the denormalized value can be used in place of a calculation.
        # It's the responsibility of observers to unset denormalized values
        #   that are triggered by changes to associated objects,
        #   so we don't check for staleness by association when looking up values
        #   ('cause it's really slow)
        def may_use_denormalized_value?(attribute_name)
          attribute_name = attribute_name.to_s.to_sym
          !self.denormalized_value_unset?(attribute_name) &&
            !self.denormalized_value_stale_by_field?(attribute_name) &&
            (
              self.class.denormalized_attributes_invalid_when_nil.blank? ||
              !self.class.denormalized_attributes_invalid_when_nil.include?(attribute_name) ||
              self.send(attribute_name).present?
            )
        end

        # Returns a true value if the attribute requires re-calculation
        def denormalized_value_stale?(attribute_name)
          attribute_name = attribute_name.to_s.to_sym
          self.class.denormalized_attribute?(attribute_name) &&
          (
            (
              self.class.denormalized_attributes_invalid_when_nil.present? &&
              self.class.denormalized_attributes_invalid_when_nil.include?(attribute_name) &&
              self.send(attribute_name).nil?
            ) ||
            denormalized_value_stale_by_field?(attribute_name) ||
            denormalized_value_stale_by_association?(attribute_name)
          )
        end

      end # InstanceMethods

    end
  end
end

ActiveRecord::Base.send :include, ActiveRecord::Acts::Denormalized
