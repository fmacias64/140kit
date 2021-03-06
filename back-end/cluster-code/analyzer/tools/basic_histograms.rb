#Results: Frequency Charts of basic data on Tweets and Users per data set
def basic_histograms(collection_id, save_path)
  collection = Collection.find({:id => collection_id})
  conditional = Analysis.conditional(collection)
  generate_graph_points([
    {"model" => Tweet, "attribute" => "language", "conditional" => conditional, "style" => "histogram", "title" => "tweet_language", "collection" => collection},
    {"model" => Tweet, "attribute" => "created_at", "conditional" => conditional, "style" => "histogram", "title" => "tweet_created_at", "collection" => collection},
    {"model" => Tweet, "attribute" => "source", "conditional" => conditional, "style" => "histogram", "title" => "tweet_source", "collection" => collection},
    {"model" => Tweet, "attribute" => "location", "conditional" => conditional, "style" => "histogram", "title" => "tweet_location", "collection" => collection},
    {"model" => User, "attribute" => "followers_count", "conditional" => conditional, "style" => "histogram", "title" => "user_followers_count", "collection" => collection},
    {"model" => User, "attribute" => "friends_count", "conditional" => conditional, "style" => "histogram", "title" => "user_friends_count", "collection" => collection},
    {"model" => User, "attribute" => "favourites_count", "conditional" => conditional, "style" => "histogram", "title" => "user_favourites_count", "collection" => collection},
    {"model" => User, "attribute" => "geo_enabled", "conditional" => conditional, "style" => "histogram", "title" => "user_geo_enabled", "collection" => collection},
    {"model" => User, "attribute" => "statuses_count", "conditional" => conditional, "style" => "histogram", "title" => "user_statuses_count", "collection" => collection},
    {"model" => User, "attribute" => "lang", "conditional" => conditional, "style" => "histogram", "title" => "user_lang", "collection" => collection},
    {"model" => User, "attribute" => "time_zone", "conditional" => conditional, "style" => "histogram", "title" => "user_time_zone", "collection" => collection},
    {"model" => User, "attribute" => "created_at", "conditional" => conditional, "style" => "histogram", "title" => "user_created_at", "collection" => collection}
  ])
  FilePathing.push_tmp_folder(save_path)
  recipient = collection.researcher.email
  subject = "#{collection.researcher.user_name}, the raw Graph data for the basic histograms in the \"#{collection.name}\" data set is complete."
  message_content = "Your CSV files are ready for download. You can grab them by visiting the collection's page: <a href=\"http://140kit.com/#{collection.researcher.user_name}/collections/#{collection.id}\">http://140kit.com/#{collection.researcher.user_name}/collections/#{collection.id}</a>."
  send_email(recipient, subject, message_content, collection)  
end

def generate_graph_points(frequency_set)
  require 'fastercsv'
  @graph_points = []
  @graphs = []
  frequency_set.each do |fs|
    time, hour, date, month, year = resolve_time(fs["granularity"], fs["time_slice"])
    graph = generate_graph({:style => fs["style"], :title => fs["title"], :collection_id => fs["collection"].id, :time_slice => time, :hour => hour, :date => date, :month => month, :year => year})
    @graphs << graph
    sub_folder = [graph.year, graph.month, graph.date, graph.hour].join("/")
    tmp_folder = FilePathing.tmp_folder(fs["collection"], sub_folder)
    if block_given?
      yield fs, graph, tmp_folder
    else frequency_graphs(fs, graph, tmp_folder)
    end
  end
  Database.update_all({:graph_points => @graph_points})
  Database.update_attributes(:graphs, @graphs, {:written => true})
end

def frequency_graphs(fs, graph, tmp_folder)
  Analysis.frequency_hash(fs["model"], fs["attribute"], fs["conditional"]) do |objects|
    temp_graph_points = []
    FasterCSV.open(tmp_folder+graph.title+".csv", "w") do |csv|
      first_hash = objects.fetch_hash
      keys = first_hash.keys
      csv << keys
      csv << keys.collect{|key| first_hash[key]}
      graph_point = {}
      graph_point["label"] = (first_hash[fs["attribute"]].class == NilClass || (first_hash[fs["attribute"]].class == String && first_hash[fs["attribute"]].empty?)) ? "Not Reported" : first_hash[fs["attribute"]].to_s.gsub("\n", " ")
      graph_point["value"] = first_hash["frequency"].to_s.gsub("\n", " ")
      graph_point["graph_id"] = graph.id
      graph_point["collection_id"] = fs["collection"].id
      temp_graph_points << graph_point
      num=1
      while row = objects.fetch_hash do
        num+=1
        csv << keys.collect{|key| row[key]}
        graph_point = {}
        graph_point["label"] = (row[fs["attribute"]].class == NilClass || (row[fs["attribute"]].class == String && row[fs["attribute"]].empty?)) ? "Not Reported" : row[fs["attribute"]].to_s.gsub("\n", " ")
        graph_point["value"] = row["frequency"].to_s.gsub("\n", " ")
        graph_point["graph_id"] = graph.id
        graph_point["collection_id"] = fs["collection"].id
        temp_graph_points << graph_point
      end
      @graph_points += Pretty.pretty_up_labels(fs["style"], fs["title"], temp_graph_points)
    end
    check_for_save
    objects.free
  end
  Database.terminate_spooling
end

def check_for_save
  if @graph_points.length > MAX_ROW_COUNT_PER_BATCH
    Database.update_all({:graph_points => @graph_points}, Environment.new_db_connect)
    @graph_points = []
  end
  if @graphs.length > MAX_ROW_COUNT_PER_BATCH
    Database.update_attributes(:graphs, @graphs, {:written => true}, Environment.new_db_connect)
    @graphs = []
  end
end

def send_email(recipient, subject, message_content, collection)
  if !collection.single_dataset
    email = PendingEmail.new({:recipient => recipient, :subject => subject, :message_content => message_content}).save
  end
end
