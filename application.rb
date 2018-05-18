require 'sinatra'
require 'sinatra/activerecord'
require 'active_support/core_ext/string/output_safety'
require 'open-uri'
require 'net/http'

require 'pry' if development?

MEGABYTE = 1024 * 1024

class File

  def each_chunk(chunk_size = MEGABYTE)
    yield read(chunk_size) until eof?
  end

end

class OpennObject < ActiveRecord::Base

end

class Application < Sinatra::Base

  def create_objects_from_payload(payload)
    payload.each do |openn, colenda|
      OpennObject.create(:openn_id => openn, :colenda_id => colenda)
    end
  end

  def fetch_from_colenda(openn_id)

    headers_hash = {'.jpg' => 'image/jpg',
                    '.tif' => 'application/octet-stream'
    }

    headers = headers_hash[File.extname(openn_id)]
    raise 'Invalid content type' if headers.nil?

    colenda_path = OpennObject.where(:openn_id => openn_id).pluck(:colenda_id)
    raise 'non-unique path value' if colenda_path.size > 1
    colenda_path = colenda_path.first

    return colenda_path, headers
  end

  def load_from_colenda(resource, &block)
    hostname = 'ceph01.library.upenn.int'
    port = 7480
    http = Net::HTTP.new(hostname,port)
    http.start do |get_call|
      req = Net::HTTP::Get.new(resource)
      get_call.request(req) do |origin_response|
        origin_response.read_body(&block)
      end
    end
  end

  get '/loadup/?' do
    sample_payload = {'Data/0001/ljs314/data/master/0179_0000.tif' => '/ark99999fk4dv2rr78/SHA256E-s125986312--3a11ab288ca29c6a470c2acbc47d12b6bcc1fb1e871b41ac5e6fa87ebbe88c5e.tif',
                      'Data/0001/ljs314/data/master/0179_0001.tif' => '/ark99999fk4dv2rr78/SHA256E-s125983512--050429a2df1543184d6fd79624df883ea5027b5591c9c5f5de311ed35f6311f2.tif',
                      'Data/0001/ljs314/data/web/0179_0000_web.jpg' => '/ark99999fk4dv2rr78/SHA256E-s846432--eaa97ac9c0fd6cc9907f4cc313141c4f21027ea5f9e024f2d11bbde59a9d3253.tif.jpeg',
                      'Data/0001/ljs314/data/web/0179_0001_web.jpg' => '/ark99999fk4dv2rr78/SHA256E-s501185--9053c49b04a2df6fbe8b5326edbf530ab59ea9eb6431c6dd463a539d9bb70f43.tif.jpeg'}
    create_objects_from_payload(sample_payload)
    return 'Objects loaded'
  end

  %w[/? /openn_up/?].each do |path|
    get path do
      @openn_objects = OpennObject.all
      erb :openn_objects
    end
  end

  get '/openn/*' do
    openn_id = params['splat'].first
    colenda_id, headers = fetch_from_colenda(openn_id)
    content_type(headers)
    stream do |obj|
      load_from_colenda(colenda_id) do |chunk|
        obj << chunk
      end
    end
  end

end