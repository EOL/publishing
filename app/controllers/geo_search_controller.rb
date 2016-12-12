require 'net/http'
require 'rest-client'
class GeoSearchController < ApplicationController
  limit = 20
  def search
    params = { borders: "POLYGON ((-120.78320312499999 39.13404537126446%2C -120.78320312499999 39.1777509666256%2C -120.75048828124999 38.1777509666256%2C -120.75048828124999 36.13404537126446%2C -120.78320312499999 35.13404537126446%2C -120.78320312499999 39.13404537126446))", taxon_selector: "" }
    loop do
      url = URI.parse("http://api.effechecka.org/checklist?limit=#{limit}&wktString=#{params[:borders]}&taxonSelector=#{params[:taxon_selector]}") 
      res = JSON.parse(Net::HTTP.get(uri))
      break if res["status"] == "ready"  
    end
    names_arr = res["items"].map{|x| x["taxon"][x["taxon"].rindex('|')+1..-1]}
    names_str = names_arr.map {|str| str.gsub('|',' ')}.join('|')
    loop do 
      res = RestClient.get(URI.escape("http://resolver.globalnames.org/name_resolvers.json?best_match_only=true&names=#{names_str}&resolve_once=true&data_source_ids=12"))
      res = JSON.parse(res.body)  
      break if res["status"] == "success"   
    end
    names_ids = res["data"].map{|x| x["results"][0]["local_id"].to_i}  
  end
end