class TagInput
  START = 30
  STEP = 40

  attr_accessor :answers, :position, :id, :answers_count, :antennas

  def initialize(id, antennae_count = 16, position = nil, antennas = nil)
    @id = id.to_s
		@antennas = antennas

    if position.present?
      @position = position
      @virtual = true
    else
      @position = Point.new(*id_to_position)
      @virtual = false
    end

    @answers = {
        :a => {:average => {}, :adaptive => {}},
        :rss => {:average => {}, :adaptive => {}},
        :rr => {:average => {}}
    }
    @answers_count = 0

    1.upto(antennae_count) do |antenna|
      @answers[:a][:average][antenna] = 0
      @answers[:a][:adaptive][antenna] = 0
    end
  end



  def clean_from_antenna(antenna_number)
    @answers[:a][:average][antenna_number] = 0
    @answers[:a][:adaptive][antenna_number] = 0
    @answers[:rss][:average].delete antenna_number
    @answers[:rss][:adaptive].delete antenna_number
    @answers[:rr][:average].delete antenna_number
    self
  end



  def nearest_antenna
    if @virtual
			if @antennas
				antennae = @antennas
			else
				antennae = (1..16).to_a.map{|antenna_number| Antenna.new(antenna_number)}
			end
      antennae.sort_by{|a| Point.distance(a.coordinates, self.position)}.first
    else
      x_code = @id[-4..-3]
      y_code = @id[-2..-1]

      tags_in_zone_row = 3

      x_antenna_number = ((tag_x_code_to_number(x_code) + 1).to_f / tags_in_zone_row).ceil
      y_antenna_number = (y_code.to_f / tags_in_zone_row).ceil

      antenna_number = y_antenna_number + (x_antenna_number - 1) * 4
      Antenna.new antenna_number
    end
  end


  def zone
    nearest_antenna.number
  end

  def in_zone?(zone_number)
    return true if zone_number.to_i == zone
    false
	end

	def in_center?()
		margin = 75.0

		if @position.x < (WorkZone::WIDTH.to_f - margin) and @position.x > margin and
				@position.y > margin and @position.y < (WorkZone::HEIGHT.to_f - margin)
			return true
		end
		false
	end




  def fill_average_mi_values(this_tag_for_each_mi, adaptive_limits)
    (1..16).each do |antenna_number|
      mi_types = [:rss, :rr, :a]
      values = {}
      this_tag_for_each_mi.each do |this_tag_for_other_mi|
        mi_types.each do |mi_type|
          values[mi_type] ||= []
          if this_tag_for_other_mi.present?
            values[mi_type].push this_tag_for_other_mi.answers[mi_type][:average][antenna_number]
          end
        end
      end
      mi_types.each do |mi_type|
        values[mi_type].map!{|v| v == nil ? MI::Base.class_by_mi_type(mi_type).default_value : v}
      end

      if values[:a].mean > 0
        rss = values[:rss].mean
        rr = values[:rr].mean
        @answers_count += 1
        @answers[:a][:average][antenna_number] = 1
        @answers[:a][:adaptive][antenna_number] = 1 if rss > adaptive_limits[:rss]
        @answers[:rss][:average][antenna_number] = rss
        @answers[:rss][:adaptive][antenna_number] = rss if rr > adaptive_limits[:rr]
        @answers[:rr][:average][antenna_number] = rr
      end
    end
  end






  class << self
    def tag_ids
      tags_ids = []

      letters = ('A'..'F')
      numbers = (1..12)

      letters.each do |letter|
        2.times do |time|
          numbers.each do |number|
            number = "%02d" % number
            if time == 0
              letter_combination = "0" + letter.to_s
            else
              letter_combination = letter.to_s * 2
            end
            tags_ids.push(letter_combination.to_s + number.to_s)
          end
        end
      end
      tags_ids
    end

    def clone(tag)
      cloned_tag = TagInput.new(tag.id)
			cloned_tag.antennas = @antennas.dup
      tag.answers.each do |answer_type, answer_hash|
        answer_hash.each do |answer_subtype, data|
          cloned_tag.answers[answer_type][answer_subtype] = data.dup
        end
      end
      cloned_tag
    end


    def from_point(point)
      return false unless point.kind_of? Point
      x = point.x
      y = point.y

      letter_array = ('A'..'F').to_a

      first_letter_code = ((x - (6*STEP + START)) / STEP)
      second_letter_code = ((x - START) / STEP)
      second_letter_code -= 6 if second_letter_code >= 6
      if first_letter_code < 0
        first_letter = '0'
      else
        first_letter = letter_array[first_letter_code.round].to_s
      end
      second_letter = letter_array[second_letter_code.round].to_s

      number = ((y - START) / STEP + 1).to_i
      digits = number.to_s
      digits = '0' + digits if number < 10
      id = first_letter + second_letter + digits

      TagInput.new(id)
    end
  end



  private


  # 0F02 => [270, 110]
  def id_to_position
    raise Exception.new('cant get id of virtual tag') if @virtual

    x_code = @id[-4..-3]
    y_code = @id[-2..-1]

    x_code_number = tag_x_code_to_number(x_code)
    y_code_number = y_code.to_i - 1

    number_to_centimeters = lambda {|number| START + (number) * STEP}
    x = number_to_centimeters.call x_code_number
    y = number_to_centimeters.call y_code_number

    [x, y]
  end
  def tag_x_code_to_number(x_code)
    raise Exception.new('cant get code of virtual tag') if @virtual
    number = letter_to_number x_code[1]
    number += 6 if x_code[0] != '0'
    number
  end
  def letter_to_number(letter)
    raise Exception.new('cant get letter of virtual tag') if @virtual
    letter.downcase.ord - 'a'.ord
  end
end
