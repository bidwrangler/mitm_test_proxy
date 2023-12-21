module MitmTestProxy
  class FileStreamer
    CHUNK_SIZE = 1024 * 16 # 16KB, adjust as needed

    def initialize(file_path)
      @file_path = file_path
    end

    def each
      File.open(@file_path, 'rb') do |file|
        while chunk = file.read(CHUNK_SIZE)
          yield chunk
        end
      end
    end
  end
end
