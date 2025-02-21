class Point
	require "inline"

	attr_accessor :x, :y

	class CCode
		inline do |builder|
			builder.c "
				double distance(double x1, double y1, double x2, double y2) {
					double x = x2 - x1;
					double y = y2 - y1;
					return sqrt(x*x + y*y);
				}
			"
			builder.c "
				int inside_rectangle(double x, double y, double lbcx, double lbcy, double width, double height) {
					if(x >= lbcx && y >= lbcy && x <= (lbcx + width) && y <= (lbcy + height)) {
						return 1;
					}
					return 0;
				}
			"
		end
	end



  def initialize(x, y)
    @x = x.to_f
    @y = y.to_f
	end

  def rotate(angle)
    hyp = Math.sqrt(@x**2 + @y**2)
    angle = Math.atan2(@y, @x) + angle
    @x = hyp*Math.cos(angle)
    @y = hyp*Math.sin(angle)
  end

  def shift(x, y)
    @x += x.to_f
    @y += y.to_f
  end

  def nil?
    return true if @x.nil? or @y.nil?
    false
  end

  def zero?
    return true if @x == 0.0 and @y == 0.0
    false
  end

  def to_a
    [@x, @y]
  end

  def to_s
    @x.to_f.to_s + "-" + @y.to_f.to_s
	end

	def eq?(point)
		return false if self.x != point.x or self.y != point.y
		true
	end

	def to_round_s(signs = 1)
		@x.to_f.round(signs).to_s + "-" + @y.to_f.round(signs).to_s
	end



  def within_tags_boundaries?
    return true if
        @x >= TagInput::START and @x <= (WorkZone::WIDTH - TagInput::START) and
        @y >= TagInput::START and @y <= (WorkZone::HEIGHT - TagInput::START)
    false
  end


  def nearest_tags_coords
    start = TagInput::START.to_f
    step = TagInput::STEP.to_f

    lower_bound = start
    upper_bound = WorkZone::WIDTH - start

    tags_coords = []


    before = ->(coord) do
      ([(coord.to_f - start), 0.0].max / step).floor * step + start
    end
    after = ->(coord) do
      return start.to_f if coord.to_f == 0.0
      ([(coord.to_f - start), 0.0].max / step).ceil * step + start
    end



    [before.call(@x), after.call(@x)].each do |x|
      [before.call(@y), after.call(@y)].each do |y|
        if x >= lower_bound and x <= upper_bound and y >= lower_bound and y <= upper_bound
          tags_coords.push(x.to_s + '-' + y.to_s)
        end
      end
    end

    tags_coords.uniq
  end


  def select_nearest_points(points)
    points_to_find_nearest = []
    points_to_find_nearest.push points.select{|p| p.y >= y and p.x <= x}
    points_to_find_nearest.push points.select{|p| p.y >= y and p.x > x}
    points_to_find_nearest.push points.select{|p| p.y < y and p.x <= x}
    points_to_find_nearest.push points.select{|p| p.y < y and p.x > x}

    nearest_points = []

    points_to_find_nearest.each do |point_group|
      nearest_points.push( point_group.sort_by{|p| Point.distance(self, p)}.first )
    end

    nearest_points.reject(&:nil?)
  end


  def approximation_proximity_coeffs(points)
    distances = []
    points.each{|p| distances.push(Point.distance(self, p))}
    coeffs = []
    inverted_distances_sum = distances.map{|d| 1.0 / d }.sum
    distances.each{|distance| coeffs.push( (1.0 / distance) / inverted_distances_sum )}
    coeffs
  end



  def angle_to_point(point)
    Math.atan2(point.y - self.y, point.x - self.x)
  end

  def distance_to_point(point)
    Math.sqrt((self.y - point.y) ** 2 + (self.x - point.x) ** 2)
  end


  def in_zone?(zone_number)
    zone_size = WorkZone::WIDTH.to_f / 4
    zone_center = Zone.new(zone_number).coordinates
    if x >= (zone_center.x - zone_size / 2) and x <= (zone_center.x + zone_size / 2) and
        y >= (zone_center.y - zone_size / 2) and y <= (zone_center.y + zone_size / 2)
      return true
    end
    false
  end



  def zone
    zones = (1..16).to_a.map{|zone_number| Zone.new(zone_number)}
    zones.sort_by{|zone| Point.distance(zone.coordinates, self)}.first
  end



  def near_zone_border?
    # max_distance = 60.0
    #puts self.to_s
    #puts self.zone.number.to_s
    #puts '_'
    distance = shortest_distance_to_zone_border(self.zone.number)

    return true if distance <= 20.0
    false
	end

	def inside_rectangle(left_bottom_corner, width, height, c_instance = nil)
		#return c_instance.inside_rectangle(@x, @y, left_bottom_corner.x, left_bottom_corner.y, width, height) if c_instance
		lbc = left_bottom_corner
		if @x >= lbc.x and @y >= lbc.y and @x <= (lbc.x + width) and @y <= (lbc.y + height)
			return true
		end
		false
	end

  def shortest_distance_to_zone_border(zone_number)
    zone = Zone.new(zone_number)
    #raise Exception.new('point inside the zone') if self.in_zone?(zone_number)

    zone_center = zone.coordinates
    zone_size = zone.size

    top_y = zone_center.y + zone.size / 2
    bottom_y = zone_center.y - zone.size / 2
    left_x = zone_center.x - zone.size / 2
    right_x = zone_center.x + zone.size / 2

    if self.in_zone?(zone_number)
      return [
          distance_to_point(Point.new(self.x, top_y)),
          distance_to_point(Point.new(self.x, bottom_y)),
          distance_to_point(Point.new(left_x, self.y)),
          distance_to_point(Point.new(right_x, self.y))
      ].min
    end


    if self.y > top_y
      if self.x < left_x
        zone_nearest_point = Point.new(zone_center.x - zone_size/2, zone_center.y + zone_size/2)
      elsif self.x > left_x
        zone_nearest_point = Point.new(zone_center.x + zone_size/2, zone_center.y + zone_size/2)
      else
        zone_nearest_point = Point.new(self.x, zone_center.y + zone_size/2)
      end
    elsif self.y < bottom_y
      if self.x < left_x
        zone_nearest_point = Point.new(zone_center.x - zone_size/2, zone_center.y - zone_size/2)
      elsif self.x > left_x
        zone_nearest_point = Point.new(zone_center.x + zone_size/2, zone_center.y - zone_size/2)
      else
        zone_nearest_point = Point.new(self.x, zone_center.y - zone_size/2)
      end
    else
      if self.x < left_x
        zone_nearest_point = Point.new(zone_center.x - zone_size/2, self.y)
      elsif self.x > right_x
        zone_nearest_point = Point.new(zone_center.x + zone_size/2, self.y)
      else
        raise Exception.new('this situation can\' be reached')
      end
    end

    Point.distance(self, zone_nearest_point)
	end


	def short_to_s
		'(' + @x.round(1).to_s + '; ' + @y.round(1).to_s + ')'
	end





  def self.from_a(coords_array)
    self.new(*coords_array.to_a)
  end

  def self.from_s(coords)
    coords_array = coords.split('-').map(&:to_f)
    coords_array = [nil, nil] if coords_array[0] == 0 and coords_array[1] == 0
    self.new(*coords_array)
  end

  def self.coords_correct?(x, y)
    return true if x >= 0 and x <= WorkZone::WIDTH and y >= 0 and y <= WorkZone::HEIGHT
    false
  end


  def self.spatial_distance_from_antenna(antenna, point)
    height = WorkZone::ROOM_HEIGHT
    Math.sqrt(height ** 2 + distance(antenna.coordinates, point) ** 2)
  end

  def self.distance(p1, p2, c_instance = nil)
		# c_instance = CCode.new
		return c_instance.distance(p1.x, p1.y, p2.x, p2.y) if c_instance
		return nil if p1.nil? or p2.nil? or p1.x.nil? or p1.y.nil? or p2.x.nil? or p2.y.nil?
		Math.sqrt((p1.x-p2.x)**2 + (p1.y-p2.y)**2)
  end

  def self.center_of_points(points, weights = [])
		center = Point.new 0.0, 0.0
		if weights.empty?
			points.each do |point|
				center.x += (point.x / points.length)
				center.y += (point.y / points.length)
			end
			center
    else
      weights_sum = weights.sum
      weights = weights.map{|w| w / weights_sum} if weights_sum != 1.0
			points.each_with_index do |point, index|
				center.x += (point.x * weights[index])
				center.y += (point.y * weights[index])
			end
			center
    end
  end




  def self.sort_polygon_vertices(polygon)
    return nil if polygon.any?{|point| ! point.is_a?(Point)}
    center = Point.center_of_points(polygon)
    polygon.sort_by{|vertex| Math.atan2(vertex.y - center.y, vertex.x - center.x)}
  end



	def self.points_in_rectangle(polygon, step = 1.0)
		return nil if polygon.any?{|vertex| ! vertex.is_a?(Point)}
		step = step.to_f
		polygon = round_polygon_vertices(polygon, step)
		min_y = polygon.map{|vertex| vertex.y}.min
		max_y = polygon.map{|vertex| vertex.y}.max
		min_x = polygon.map{|vertex| vertex.x}.min
		max_x = polygon.map{|vertex| vertex.x}.max
		points = []
		(min_x..max_x).step(step).each do |x|
			(min_y..max_y).step(step).each do |y|
				points.push Point.new(x,y)
			end
		end
		points
	end

  def self.points_in_polygon(polygon, step = 1.0)
    return nil if polygon.any?{|vertex| ! vertex.is_a?(Point)}
    step = step.to_f
		polygon = round_polygon_vertices(polygon, step)
    polygon = sort_polygon_vertices(polygon)

    min_y = polygon.map{|vertex| vertex.y}.min
    max_y = polygon.map{|vertex| vertex.y}.max

    x_boundaries = {}
    (min_y..max_y).step(step) do |y|
      x_boundaries[y] = {:min => WorkZone::WIDTH.to_f, :max => 0.0}
    end


    polygon.each_with_index do |vertex, i|
      next_vertex = polygon[i + 1]
      next_vertex = polygon[0] if next_vertex.nil?

      all_points_through_vertices_line = []
      start_y = [vertex.y, next_vertex.y].min
      end_y = [vertex.y, next_vertex.y].max
      (start_y..end_y).step(step) do |y|
        x = (y - vertex.y) / (next_vertex.y - vertex.y) * (next_vertex.x - vertex.x) + vertex.x
        x = vertex.x if x.nan?
        all_points_through_vertices_line.push Point.new(x, y)
      end


      #puts start_y.to_s + ' and ' + end_y.to_s
      #puts vertex.to_s + ' and ' + next_vertex.to_s
      #puts all_points_through_vertices_line.to_s
      #puts ''
      #
      #puts x_boundaries.to_s

      all_points_through_vertices_line.each do |point|
        #puts 'this'+ point.y.to_s + '  ' + x_boundaries[point.y].to_s + ' ' + point.to_s
        x_boundaries[point.y][:max] = point.x if point.x > x_boundaries[point.y][:max]
        x_boundaries[point.y][:min] = point.x if point.x < x_boundaries[point.y][:min]
      end

      #puts x_boundaries.to_s
      #puts ''
      #puts ''
      #puts ''
    end



    points = []
    x_boundaries.each do |y, x_boundary|
      (x_boundary[:min]..x_boundary[:max]).step(step) do |x|
        points.push Point.new(x, y)
      end
    end

    points
  end

	def self.round_polygon_vertices(polygon, step)
		polygon.map{|vertex| Point.new( (vertex.x/step).round*step, (vertex.y/step).round*step )}
	end
end





