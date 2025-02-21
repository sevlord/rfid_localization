class Algorithm::PointBased < Algorithm::Base

  attr_reader :cdf, :pdf, :map, :errors_parameters, :errors, :group
  attr_accessor :best_suited


  def initialize(reader_power, manager_id, group, train_data, model_must_be_retrained, apply_means_unbiasing, antennae = WorkZone.create_default_antennae(16, 70, [250,160], [300,190], Math::PI/4, :grid))
    super(reader_power, manager_id, train_data, model_must_be_retrained, antennae)
    @apply_means_unbiasing = apply_means_unbiasing
    @group = group
		#@rinruby = RinRuby.new(echo = false)
	end



  private



  def specific_output(model, test_data, index)
    @cdf ||= {}
    @pdf ||= {}
    @errors_parameters ||= {}
    @errors ||= {}
    @best_suited ||= {}

    output = calc_tags_estimates(model, @setup, test_data, index)

    @errors[index] = output.values.reject{|tag|tag.error.nil? or tag.error.nan?}.map{|tag| tag.error.to_f}.sort

    @map[index] = {}
    test_data.each do |tag_index, tag|
      if output[tag_index] != nil and tag != nil
        @map[index][tag_index] = {
            :position => tag.position,
            :zone => Zone.new(tag.zone).coordinates,
            :answers_count => tag.answers_count,
            :estimate => output[tag_index].estimate,
            :error => output[tag_index].error
        }
      end
    end

    @cdf[index] = create_cdf(@errors[index])
    @pdf[index] = create_pdf(@errors[index])

    @errors_parameters[index] = calc_localization_parameters(output, test_data, @errors[index])

    @best_suited[index] = create_best_suited_hash
  end






  def calc_tags_estimates(model, setup, input_tags, height_index)
    tags_estimates = {}

    input_tags.each do |tag_index, tag|
      estimate = model_run_method(model, setup[height_index], tag)
      if estimate.nil? or estimate.zero?
				nil
			else
        tag_output = TagOutput.new(tag, estimate)
        tags_estimates[tag_index] = tag_output
      end
		end

    tags_estimates
  end






  def set_up_model(model, train_data, setup_data, height_index)
    return nil if setup_data.nil?
    #return nil

    estimate_errors = {}

		errors = {total: {}, x: {}, y: {}}
    estimates = {}
    setup_data.each do |tag_index, tag|
      estimate = model_run_method(model, nil, tag)
      estimates[tag_index] = estimate
      errors[:total][tag_index] = Point.distance(estimate, tag.position)
      errors[:x][tag_index] = estimate.x - tag.position.x
      errors[:y][tag_index] = estimate.y - tag.position.y
      #error = Point.distance(tag.position, estimate)

			[tag.answers_count, :four_and_more, :all].each do |count|
				estimate_errors[count] ||= {:x => [], :y => [], :total => []}
				if count != :four_and_more or (count == :four_and_more and tag.answers_count >= 3)
					estimate_errors[count][:x].push( tag.position.x - estimate.x )
					estimate_errors[count][:y].push( tag.position.y - estimate.y )
					estimate_errors[count][:total].push( Point.distance(tag.position, estimate) )
				end
			end
		end

    means = {}
    stddevs = {}
    lengths = {}
    estimate_errors.each do |antennae_count, errors_for_current_antennae_count|
      lengths[antennae_count] = errors_for_current_antennae_count[:x].length
      means[antennae_count] = {
          :x => errors_for_current_antennae_count[:x].mean,
          :y => errors_for_current_antennae_count[:y].mean,
          :total => errors_for_current_antennae_count[:total].mean
      }
      stddevs[antennae_count] = {
          :x => errors_for_current_antennae_count[:x].stddev,
          :y => errors_for_current_antennae_count[:y].stddev,
          :total => errors_for_current_antennae_count[:total].stddev
      }
    end

    retrained_model = retrain_model(train_data, setup_data, @heights_combinations[height_index])


		#puts means.to_yaml
		#puts stddevs.to_yaml
		#puts ''

    {
        :stddevs => stddevs,
        :means => means,
        :lengths => lengths,
        :estimates => estimates,
        :errors => errors,
        :retrained_model => retrained_model
    }
  end




  def remove_bias(tag, setup, estimate)
    if @apply_means_unbiasing
      unless setup.nil?
        if setup[:lengths][:all].to_i > 5
          estimate.x -= setup[:means][:all][:x]
          estimate.y -= setup[:means][:all][:y]
        end
      end
    end
    estimate
  end





















  def calc_localization_parameters(output, input, errors)
    parameters = {
        :total => {},
        :x => {},
        :y => {},
        :by_antenna_count => {:variances => {}, :errors => {}, :lengths => {}, :means => {}}
    }
    parameters[:total][:max] = errors.max.round(1)
    parameters[:total][:min] = errors.min.round(1)

    quantile = ->(p) do
      n = errors.length
      k = (p * (n - 1)).floor
      return errors[k + 1] if (k + 1) < p * n
      return (errors[k] + errors[k + 1]) / 2 if (k + 1) == p * n
      return errors[k] if (k + 1) > p * n
      nil
    end

    parameters[:total][:percentile10] = quantile.call(0.1)
    parameters[:total][:quartile1] = quantile.call(0.25)
    parameters[:total][:median] = quantile.call(0.5)
    parameters[:total][:quartile3] = quantile.call(0.75)
    parameters[:total][:percentile90] = quantile.call(0.9)

    parameters[:total][:before_percentile10] =
        errors.select{|error| error < (parameters[:total][:percentile10] - 1)}
    parameters[:total][:above_percentile90] =
        errors.select{|error| error > (parameters[:total][:percentile90] + 1)}

    parameters[:total][:mean] = errors.mean.round(1)
    parameters[:total][:stddev] = errors.stddev.round(1)
    parameters[:total][:rayleigh_sigma] = (errors.map{|v| v**2}.mean / 2).round(2)

		#confidence_level = 0.975
		#@rinruby.eval "quantile1 <- toString(qchisq(#{confidence_level/2}, df=#{(2*errors.length).to_s}))"
		#@rinruby.eval "quantile2 <- toString(qchisq(#{1-confidence_level/2}, df=#{(2*errors.length).to_s}))"
		#quantile1 = @rinruby.pull("quantile1").to_f
		#quantile2 = @rinruby.pull("quantile2").to_f
		#parameters[:total][:left_limit] = 2.0 * errors.mean * errors.length / quantile2
		#parameters[:total][:right_limit] = 2.0 * errors.mean * errors.length / quantile1
		#z = 1.96
		#interval = z * Math.sqrt( (errors.map{|v| v**2}.sum ** 2) / (4.0*errors.length**3) )
		#
		#sigma_square = errors.mean*Math.sqrt(2.0/Math::PI)
		#interval2 = z * Math.sqrt(
		#		( 2.0 * (4.0 - Math::PI) * sigma_square ** 2 ) / (2.0 * Math::PI * errors.length)
		#)
		#limit3_1 = errors.map{|e|e**2}.mean * errors.length / quantile2
		#limit3_2 = errors.map{|e|e**2}.mean * errors.length / quantile1
		#
		#
		#puts quantile1.to_s
		#puts quantile2.to_s
		#puts errors.mean.to_s
		#puts errors.length
		#puts (errors.map{|v| v**2}.mean / 2).to_s
		#puts (errors.map{|v| v**2}.mean).to_s
		#puts (1-confidence_level/2).to_s
		#puts 2.0 * errors.mean * errors.length / quantile1
		#puts 2.0 * errors.mean * errors.length / quantile2
		#puts 2.0 * errors.map{|v| v**2}.mean * errors.length / quantile1
		#puts 2.0 * errors.map{|v| v**2}.mean * errors.length / quantile2
		#puts interval.to_s
		#puts interval2.to_s
		#puts limit3_1.to_s
		#puts limit3_2.to_s
		#puts Math.sqrt(interval).to_s
		#puts (Math.sqrt(interval) * Math.sqrt(Math::PI/2)).to_s

		if errors.length > 5
			z = 1.96
			sigma_square = errors.map{|v| v**2}.sum / (2.0 * errors.length)
			interval = z * Math.sqrt( (errors.map{|e| e**2}.sum ** 2) / (4.0*errors.length**3) )
			range = [sigma_square - interval, sigma_square + interval]
			range = range.map{|l| Math.sqrt(l) * Math.sqrt(Math::PI/2)}
			parameters[:total][:interval] = range.max - range.mean
			parameters[:total][:interval2] =
					(1.0/4) * Math.sqrt(Math::PI/errors.length) * Math.sqrt(errors.map{|e| e**2}.sum) *
					(Math.sqrt(1.0 + z/Math.sqrt(errors.length)) - Math.sqrt(1.0 - z/Math.sqrt(errors.length)))
		end



    shifted_estimates = {:x => [], :y => []}
    output.each do |tag_index, tag_output|
      tag_input = input[tag_index]
      unless tag_output.estimate.nil?
        shifted_estimates[:x].push(tag_output.estimate.x - tag_input.position.x)
        shifted_estimates[:y].push(tag_output.estimate.y - tag_input.position.y)

        parameters[:by_antenna_count][:errors][tag_input.answers_count] ||= []
        parameters[:by_antenna_count][:lengths][tag_input.answers_count] ||= 0

        parameters[:by_antenna_count][:errors][tag_input.answers_count].push tag_output.error
        parameters[:by_antenna_count][:lengths][tag_input.answers_count] += 1
      end
    end

    (1..16).each do |answers_count|
      errors_for_current_answers_count = parameters[:by_antenna_count][:errors][answers_count]
      if errors_for_current_answers_count.present?
        parameters[:by_antenna_count][:variances][answers_count] =
            parameters[:by_antenna_count][:errors][answers_count].variance
        parameters[:by_antenna_count][:means][answers_count] =
            parameters[:by_antenna_count][:errors][answers_count].mean
      end
    end


    parameters[:x][:mean] = shifted_estimates[:x].mean.round(1)
    parameters[:x][:stddev] = shifted_estimates[:x].stddev.round(1)
    parameters[:y][:mean] = shifted_estimates[:y].mean.round(1)
    parameters[:y][:stddev] = shifted_estimates[:y].stddev.round(1)

    parameters
  end






  def max_error_value
    1000
  end

  def create_best_suited_hash
    hash = {:all => 0}
    (1..16).each {|antennae_count| hash[antennae_count] = 0}
    hash
  end



  # http://e-science.ru/math/FAQ/Statistic/Basic.html#b1415
  def create_cdf(errors)
    cdf = []
    n = errors.size

    errors.each_with_index do |error, m|
      if m == 0
        cdf.push [0, 0]
        cdf.push [errors.min, 0]
      elsif m == n
        cdf.push [errors.max, 1]
        cdf.push [errors.max + max_error_value, 1]
      else
        cdf.push [errors[m], m.to_f / n]
        cdf.push [errors[m+1], m.to_f / n]
      end
    end

    cdf
  end

  def create_pdf(errors)
    data = errors
    step = 5

    histogram = []
    (0..data.max).step(step) do |from|
      to = from + step
      histogram.push [from, data.select{|e| from <= e and e < to }.count]
    end
    histogram
  end






  #def calc_antennae_coefficients
  #  antennae_coefficients = {}
  #  tags_input = {}
  #  tags_output = {}
  #
  #  (1..16).each do |antenna_number|
  #    antennae_coefficients[antenna_number] = []
  #    tags_input[antenna_number] = clean_tags_from_antenna(antenna_number)
  #    tags_output[antenna_number] = calc_tags_output(tags_input[antenna_number])
  #  end
  #
  #  @tags_test_input.each do |tag_index, tag|
  #    if tag.answers_count > 1
  #      total_error = tag.answers[:rss][:average].map do |antenna,answer|
  #        tags_output[antenna][tag_index].error
  #      end.inject(&:+)
  #
  #      tag.answers[:a][:average].reject{|antenna,answer| answer == 0}.each do |antenna_number, answer|
  #        percent = tags_output[antenna_number][tag_index].error / total_error
  #        antennae_coefficients[antenna_number].push(percent)
  #      end
  #    end
  #  end
  #
  #  (1..16).each do |antenna_number|
  #    antennae_coefficients[antenna_number] = antennae_coefficients[antenna_number].inject(&:+) / antennae_coefficients[antenna_number].length
  #  end
  #  max = antennae_coefficients.values.max
  #  (1..16).each do |antenna_number|
  #    antennae_coefficients[antenna_number] = antennae_coefficients[antenna_number] / max
  #  end
  #
  #  antennae_coefficients
  #end

  #def clean_tags_from_antenna(antenna_number)
  #  tags_input = {}
  #  @tags_test_input.each do |tag_index, tag|
  #    tags_input[tag_index] = TagInput.clone(tag).clean_from_antenna(antenna_number)
  #  end
  #  tags_input
  #end

end