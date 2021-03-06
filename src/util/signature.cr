require "./util"

class File
  abstract struct Info
    def inode : UInt64
      @stat.st_ino.to_u64
    end
  end

  # Returns the signature of the file at filename.
  # When it is not a supported file, returns 0. Otherwise, uses the inode
  #   number as its signature. On most file systems, the inode number is
  #   preserved even when the file is renamed, moved or edited.
  # Some cases that would cause the inode number to change:
  #   - Reboot/remount on some file systems
  #   - Replaced with a copied file
  #   - Moved to a different device
  # Since we are also using the relative paths to match ids, we won't lose
  #   information as long as the above changes do not happen together with
  #   a file/folder rename, with no library scan in between.
  def self.signature(filename) : UInt64
    if is_supported_file filename
      File.info(filename).inode
    else
      0u64
    end
  end
end

class Dir
  # Returns the signature of the directory at dirname. See the comments for
  #   `File.signature` for more information.
  def self.signature(dirname) : UInt64
    signatures = [File.info(dirname).inode]
    self.open dirname do |dir|
      dir.entries.each do |fn|
        next if fn.starts_with? "."
        path = File.join dirname, fn
        if File.directory? path
          signatures << Dir.signature path
        else
          _sig = File.signature path
          # Only add its signature value to `signatures` when it is a
          #   supported file
          signatures << _sig if _sig > 0
        end
      end
    end
    Digest::CRC32.checksum(signatures.sort.join).to_u64
  end
end
