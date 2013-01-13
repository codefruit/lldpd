require 'formula'

class Lldpd < Formula
  homepage 'http://vincentbernat.github.com/lldpd/'
  url 'http://media.luffy.cx/files/lldpd/lldpd-0.7.1.tar.gz'
  md5 'cee0e2ae7d4b8bf25ae234d9536052b8'

  # Included copy of libevent does not like automake 1.13
  # head 'git://github.com/vincentbernat/lldpd.git'

  option 'with-snmp', "Build SNMP subagent support"
  option 'with-json', "Build JSON support for lldpcli"

  depends_on 'readline'
  depends_on 'libevent'
  depends_on 'pkg-config'
  depends_on 'net-snmp' if build.include? 'with-snmp'
  depends_on 'jansson'  if build.include? 'with-json'
  depends_on 'autoconf' if build.head?
  depends_on 'automake' if build.head?
  depends_on 'libtool'  if build.head?

  def install
    readline = Formula.factory 'readline'
    if build.head?
      system "env LIBTOOLIZE=glibtoolize ./autogen.sh"
    end
    args = [ "--prefix=#{prefix}",
             "--with-xml",
             "--with-readline",
             "--with-privsep-chroot=/var/empty",
             "CPPFLAGS=-I#{readline.include} -DRONLY=1",
             "LDFLAGS=-L#{readline.lib}" ]
    args << "--with-snmp" if build.include? 'with-snmp'
    args << "--with-json" if build.include? 'with-json'

    system "./configure", *args
    system "make"
    system "make install"
  end

  def dscl(*args)
    result = `dscl . -#{args.join(' ')} 2> /dev/null`
    if $? != 0
      raise ErrorDuringExecution, "Failure while executing dscl: #{args.join(' ')}"
    end
    return result
  end

  # Create user and group if needed
  def caveats
    u = "_lldpd"
    unless Kernel.system "/usr/bin/dscl . -read /Users/#{u} &> /dev/null"
      # Find a free UID/GID
      uids = dscl("list /Users uid")
      gids = dscl("list /Groups gid")
      uid = 200
      while uids =~ Regexp.new("#{Regexp.escape(uid.to_s)}\n") || gids =~ Regexp.new("#{Regexp.escape(uid.to_s)}\n")
        uid += 1
      end
      s = <<-EOS.undent
        You need to create a special user to run lldpd.
        Just type the following commands:
            sudo dscl . -create /Groups/#{u}
            sudo dscl . -create /Groups/#{u} PrimaryGroupID #{uid.to_s}
            sudo dscl . -create /Groups/#{u} Password "*"
            sudo dscl . -create /Groups/#{u} RealName "lldpd privilege separation group"
            sudo dscl . -create /Users/#{u}
            sudo dscl . -create /Users/#{u} UserShell /usr/bin/false
            sudo dscl . -create /Users/#{u} NFSHomeDirectory /var/empty
            sudo dscl . -create /Users/#{u} PrimaryGroupID #{uid.to_s}
            sudo dscl . -create /Users/#{u} UniqueID #{uid.to_s}
            sudo dscl . -create /Users/#{u} Password "*"
            sudo dscl . -create /Users/#{u} RealName "lldpd privilege separation user"
      EOS
      return s
    end
  end

  plist_options :startup => true
  def plist
    additional_args = ""
    if build.include? 'with-snmp'
      additional_args += "<string>-x</string>"
    end
    return <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_prefix}/sbin/lldpd</string>
        #{additional_args}
      </array>
      <key>RunAtLoad</key><true/>
      <key>KeepAlive</key><true/>
    </dict>
    </plist>
    EOS
  end

end
