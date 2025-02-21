class Algorithm::PointBased::Trilateration < Algorithm::PointBased

  def trainable
    false
  end




  def set_settings(mi_model_type, metric_name, optimization_class, antenna_type, model_type, rr_limit, ellipse_ratio)
		@mi_model_type = mi_model_type
		@metric_name = metric_name
    @metric_type = :average
    @mi_class = MI::Base.class_by_mi_type(metric_name)
    @optimization = optimization_class.new
    @regression_type = 'new'
    @model_type = model_type
    @antenna_type = antenna_type
    @rr_limit = rr_limit
    @ellipse_ratio = ellipse_ratio
    self
  end





  def get_decision_function
    step = 10
    decision_functions = {}
    mi = {}

    @train_height = 0

    @tags_input[0][:test].each do |tag_index, tag|
      mi_hash = @optimization.optimize_data( tag.answers[@metric_name][@metric_type] )
      decision_functions[tag_index] = {}

      mi[tag_index] = {
          :mi => tag.answers[@metric_name][@metric_type],
          :filtered => mi_hash
      }
      (0..@work_zone.width).step(step) do |x|
        (0..@work_zone.height).step(step) do |y|
          point = Point.new(x, y)
          decision_functions[tag_index][x] ||= {}
          decision_functions[tag_index][x][y] = calc_result_for_point(point, mi_hash)
        end
      end

    end

    {
        :mi => mi,
        :extremum_criterion => @optimization.estimation_extremum_criterion,
        :data => decision_functions
    }
  end












  private




  def train_model(tags_train_input, height, model_id)
    height
  end


  def model_run_method(height, setup, tag)
    if height.is_a? Array
      @train_height = height.first
    else
      @train_height = height
    end


    mi_hash = tag.answers[@metric_name][@metric_type]
    mi_hash = mi_hash.dup.keep_if{|k,v| tag.answers[:rr][:average][k] > @rr_limit}
    mi_hash = tag.answers[@metric_name][:average] if mi_hash.empty?

    antennas = mi_hash.keys
    start_point = Point.center_of_points(antennas.map{|n| Antenna.new(n).coordinates})

    #puts mi_hash.length.to_s

    if mi_hash.length == 1
      current_point = point_for_one_antenna_case(mi_hash)
      #current_point = Point.new(nil,nil)
    elsif mi_hash.length == 2
      current_point = point_for_two_antennae_case(mi_hash)
      #current_point = Point.new(nil,nil)
    #elsif mi_hash.length == 3
    #  current_point = Point.new(nil,nil)

    else
      #step = 1.0
      #polygon = mi_hash.keys.map{|a| @work_zone.antennae[a].coordinates}
      #
      #points = Rails.cache.fetch('polygon_points_'+polygon.sort_by{|p| [p.x, p.y]}.to_s + step.to_s, :expires_in => 5.day) do
      #  Point.points_in_polygon(polygon, step)
      #end
      #
      #data = {}
      #points.each do |point|
      #  data[point] = calc_result_for_point(point, mi_hash)
      #end
      #
      ##puts ''
      ##puts polygon.to_s
      ##puts Point.points_in_polygon(polygon, @step).to_s
      ##puts points.to_s
      ##puts decision_functions.to_yaml
      #
      #current_point = data.sort_by{|point, v| v}.first.first

      points = {}

      current_point = start_point
      previous_point_result = 0.0

      while true
        current_point_result = calc_result_for_point(current_point, mi_hash)

				if (current_point_result - previous_point_result).abs < @optimization.epsilon
					break
				end
        previous_point_result = current_point_result

        current_point = next_point_via_gradient(current_point, current_point_result, mi_hash)
				if current_point.nil?
					break
				end

        if points.keys.any? {|p| Point.distance(p, current_point) < 0.0001}
					sorted_points = points.sort_by{|p, v| v}
          sorted_points = sorted_points.reverse if @optimization.reverse_decision_function?
          current_point = sorted_points.first.first
          break
        end
        points[current_point] = current_point_result
      end
    end

    estimate = current_point
    remove_bias(tag, setup, estimate)
  end







  def next_point_via_gradient(point, current_point_result, mi_hash)
    gradient_step = 0.1

    nearest_points = calc_nearest_points(point, gradient_step)
    nearest_points_results = nearest_points.map do |p|
      calc_result_for_point(p, mi_hash)
		end

    coeff_x = (nearest_points_results[0] - current_point_result) / gradient_step
    coeff_y = (nearest_points_results[1] - current_point_result) / gradient_step
    angle = Math.atan2(coeff_y, coeff_x)
    angle = opposite_angle(angle) unless @optimization.reverse_decision_function?

    next_point = one_dimensional_optimization(point, angle, mi_hash)

    return nil if next_point.x > WorkZone::WIDTH or next_point.y > WorkZone::HEIGHT
    next_point
  end


  def opposite_angle(angle)
    if angle < 0.0
      angle + Math::PI
    else
      angle - Math::PI
    end
  end


  def one_dimensional_optimization(start_point, angle, mi_hash)
    width = WorkZone::WIDTH
    height = WorkZone::HEIGHT

    distance_epsilon = 2.0

    if angle.between?(0, Math::PI/2) # 1
      angle_parameters = [Math.cos(angle), Math.sin(angle)]
      a = [width - start_point.x, height - start_point.y]
      angles = [angle, Math::PI/2 - angle]
    elsif angle.between?(Math::PI/2, Math::PI) # 2
      new_angle = Math::PI - angle
      angle_parameters = [- Math.cos(new_angle), Math.sin(new_angle)]
      a = [start_point.x, height - start_point.y]
      angles = [Math::PI - angle, angle - Math::PI/2]
    elsif angle.between?(-Math::PI/2, 0) # 3
      new_angle = angle.abs
      angle_parameters = [Math.cos(new_angle), - Math.sin(new_angle)]
      a = [width - start_point.x, start_point.y]
      angles = [angle.abs, Math::PI/2 - angle.abs]
    else # 4
      new_angle = Math::PI - angle.abs
      angle_parameters = [- Math.cos(new_angle), - Math.sin(new_angle)]
      a = [start_point.x, start_point.y]
      angles = [Math::PI - angle.abs, angle.abs - Math::PI/2]
    end

    hypotenuse = [a[0] / Math.cos(angles[0]), a[1] / Math.cos(angles[1])].min

    end_point = point_by_ray(start_point, hypotenuse, angle_parameters)

    a = start_point
    b = end_point



    while true
      center = Point.center_of_points([a,b])
      distance = Point.distance(a, center)

      x1 = point_by_ray(a, 0.99 * distance, angle_parameters)
      x2 = point_by_ray(a, 1.01 * distance, angle_parameters)
      y1 = calc_result_for_point(x1, mi_hash)
      y2 = calc_result_for_point(x2, mi_hash)

      if y2.send(@optimization.gradient_compare_operator, y1)
        a = x1
      else
        b = x2
      end

      if Point.distance(b, a).abs < distance_epsilon
        return Point.center_of_points([a, b])
      end
    end

  end

  def point_by_ray(start, hypotenuse, angle_parameters)
    Point.new( start.x + hypotenuse * angle_parameters[0], start.y + hypotenuse * angle_parameters[1] )
  end


  def calc_nearest_points(point, step)
    nearest_points = [point.dup, point.dup]
    nearest_points[0].x += step
    nearest_points[1].y += step
    return nil if nearest_points.any?{|p| p.nil?}
    nearest_points
  end




  def calc_result_for_point(point, mi_hash)
    distances = get_distances_by_mi(mi_hash, point)
		@results ||= {}
    cache_name = point.to_s + distances.to_s
    @results[cache_name] = error_for_antennas_with_answers(point, distances, mi_hash)
    @results[cache_name]
  end

  def error_for_antennas_with_answers(point, distances_by_mi, mi_hash)
    real_distances = {}
    distances_by_mi.keys.map do |antenna_number|
      antenna = @work_zone.antennae[antenna_number]
      real_distances[antenna_number] = Point.distance(antenna.coordinates, point)
		end
		#puts real_distances.to_s
    @optimization.compare_vectors(
        real_distances,
        distances_by_mi,
        {},
        double_sigma_power
    )
  end






  #def make_weights(mi_hash)
  #  shift = 0.00001
  #  weights = {}
  #  inverted_denominator = mi_hash.values.map{|e| 1.0 / ((e.abs - @mi_class.range[0].abs).to_f + shift) }.sum
  #  mi_hash.each do |antenna, mi|
  #    weights[antenna] = (1.0 / ((mi.abs - @mi_class.range[0].abs).to_f + shift)) / inverted_denominator
  #  end
  #  weights
  #end


  def make_weights(mi_hash)
    weights = {}
    range = (@mi_class.range[0] - @mi_class.range[1]).abs
    mi_hash.each do |antenna, mi|
      weights[antenna] = ((mi.abs - @mi_class.range[0].abs) - range).abs / range
    end
    weights
  end


  def get_distances_by_mi(mi_hash, point)
    #puts @mi_class.to_s
    #puts mi_hash.to_s
    #puts @mi_class.angles_hash(mi_hash, point).to_s
    #puts @reader_power.to_s
    #puts @regression_type.to_s
    #puts @train_height.to_s
    #puts @antenna_type.to_s
    #puts @model_type.to_s

    @mi_class.distances_hash(
        mi_hash,
        @mi_class.angles_hash(mi_hash, point),
        @reader_power,
        @regression_type,
        @train_height,
        @antenna_type,
        @model_type,
        @ellipse_ratio,
				@work_zone,
				point
    )
  end




  def double_sigma_power
    return 10_000 if @metric_name == :rss
    return 2 if @metric_name == :rr
    nil
  end



	def point_for_one_antenna_case(mi_hash)
		antenna_number = mi_hash.keys.first
		antenna = @work_zone.antennae[antenna_number]
		coords = antenna.coordinates

		if antenna.near_walls? and @mi_model_type != :theoretical
			mi = mi_hash.values.first.abs

			if @metric_name == :rss
				mi_range = @mi_class.range.map{|v|v.abs}
				difference = mi_range[1] - mi_range[0]
				weights = []
				if mi < mi_range[1]
					weights = [(mi_range[1] - mi).abs / difference, (mi - mi_range[0]).abs / difference]
				end
			else
				weights = [mi.to_f, 1.0 - mi.to_f]
			end

			coords = Point.center_of_points([coords, antenna.nearest_wall_point], weights)
		end

		Point.new(coords.x, coords.y)
	end

	def point_for_two_antennae_case(mi_hash)
		min = @mi_class.range[0].abs

		antennae_coords = @work_zone.
				antennae.
				select{|n,a| mi_hash.keys.include? n}.
				values.
				map{|a| a.coordinates}
		mi_array = mi_hash.values.map(&:abs)

		if @metric_name == :rss
			total = mi_array.sum - 2 * min

			weights = []
			if min < mi_array.min
				weights = [
						(mi_array[1] - min).abs.to_f / total,
						(mi_array[0] - min).abs.to_f / total
				]
			end
		else
			total = mi_array.sum
			weights = [mi_array[0].to_f / total, mi_array[1].to_f / total]
		end

		Point.center_of_points(antennae_coords, weights)
	end
end