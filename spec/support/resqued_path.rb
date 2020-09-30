module ResquedPath
  def resqued_path
    return @resqued_path if @resqued_path

    @resqued_path = File.expand_path("../../gemfiles/bin/resqued", File.dirname(__FILE__))
    unless File.executable?(@resqued_path)
      @resqued_path = File.expand_path("../../bin/resqued", File.dirname(__FILE__))
    end
    @resqued_path
  end
end
