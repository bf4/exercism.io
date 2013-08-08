class Dashboard

  class Filters
    attr_reader :submissions

    def initialize(submissions)
      @submissions ||= submissions
    end

    def users
      @users ||= submissions.map {|sub| sub.user.username}.uniq.sort
    end

    def exercises
      @exercises ||= submissions.map(&:slug).uniq.sort
    end

    def languages
      @languages ||= submissions.map(&:language).uniq.sort
    end
  end

  class Curriculum

    attr_reader :languages
    def initialize(languages)
      @languages = languages
    end

    def assignments
      order_slugs_by_quantity(slugs_by_language).
        flatten.
        uniq
    end

    private
    def slugs_by_language
      languages.map { |language| slugs(language) }
    end

    def order_slugs_by_quantity(all_slugs)
      all_slugs.sort_by { |slugs| slugs.length }
    end

    def slugs(language)
      Exercism.const_get("#{language}_curriculum".classify).new.slugs
    end
  end

  class Submissions
    attr_reader :submissions
    def initialize(submissions)
      @submissions = submissions
    end

    def all
      pending
    end

    def any?
      not all.empty?
    end

    def pending
      submissions
    end

    def no_nits_on_this_iteration
      @not_recently_nitted ||= pending.select { |sub| sub.no_nits_yet? }.reverse
    end

    def never_been_nitted
      @never_nitted ||= no_nits_on_this_iteration.select { |sub| sub.no_version_has_nits? }
    end # must be a strict subset of those without nits on this iteration...

    def nits_before_but_not_on_this_iteration
      @nits_before ||= (no_nits_on_this_iteration - never_been_nitted)
    end

    def without_nits
      no_nits_on_this_iteration
    end

    def with_nits
      @with_nits ||= pending.select { |sub| sub.this_version_has_nits? }
    end

    def flagged_for_approval
      []
    end
  end

  class AdminSubmissions < Submissions
    def all
      submissions
    end

    def pending
      @pending ||= submissions.select { |sub| !sub.approvable? }
    end

    def flagged_for_approval
      @flagged_for_approval ||= submissions.select { |sub| sub.approvable? }
    end
  end

  attr_reader :user, :all_submissions
  def initialize(user, all_submissions)
    @user = user
    @all_submissions = all_submissions
  end

  def submissions
    return @submissions if @submissions

    if user.admin?
      @submissions ||= AdminSubmissions.new(all_submissions)
    else
      submissions = all_submissions.select do |sub|
        user.may_nitpick?(sub.exercise)
      end
      @submissions ||= Submissions.new(submissions)
    end
  end

  def filters
    @filters ||= Filters.new(submissions.all)
  end

  def curriculum
    @curriculum ||= Curriculum.new(filters.languages)
  end
end

