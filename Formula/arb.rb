class Arb < Formula
  desc "Graphical DNA, RNA and amino acid sequence analysis tool"
  homepage "http://www.arb-home.de"

  # wil be activated when ARB 6.1 has been released
  # ARB release version - called stable in homebrew
  # stable do
  #   url "http://download.arb-home.de/release/arb-6.0.6/arb-6.0.6-source.tgz"
  #   sha256 "8b1fc3fd11bbb05aca4731ac8803c004a4f2b6b87c11b543660d07ea349a6c21"
  # end

  # ARB production version - called devel in homebrew
  devel do
    url "http://download.arb-home.de/special/manual-builds/2020_02_21/arb-r18314-source.tgz"
    sha256 "b302bc560e3315f0b7b464f6a6e20f45807027c6e8e189d76cd4dd8597dda0ae"
    version "6.1-beta_r18314"
  end

  # ARB development version - called HEAD in homebrew
  head do
    url "http://vc.arb-home.de/readonly/trunk", :using => :svn
  end

  ##############################################################################
  ### OPTIONS                                                                ###
  ##############################################################################
  # currently broken, GLAPI is missing, not sure which package should provide it
  option "with-open-gl", "Include ARB features that use OpenGL. Broken - WIP."

  # for internal / ARB developer use only
  option "with-test", "Execute unit tests during build. Not intended for end-users."

  # enable debug symbols in binaries
  option "with-debug", "Enable debug symbols in binaries. Not intended for end-users."

  ##############################################################################
  ### DEPENDENCIES - homebrew style is to sort blocks alphabetically         ###
  ##############################################################################

  depends_on "makedepend" => :build
  depends_on "pkg-config" => :build

  depends_on :arch => :x86_64
  depends_on "boost"
  depends_on "coreutils"
  depends_on "gettext"
  depends_on "glib"
  depends_on "gnu-sed"
  depends_on "gnu-time"
  depends_on "gnuplot"
  depends_on "gv"
  depends_on "lynx"
  depends_on "openmotif"
  depends_on "perl@5.18"
  depends_on :x11
  depends_on "xerces-c"
  depends_on "xfig"

  # OpenGL dependencies, only used if build with '--with-open-gl'
  if build.with?("open-gl")
    depends_on "glfw"
    depends_on "mesalib-glw"
    depends_on "glew"
    depends_on "freeglut"
    # "Glbinding"
  end

  # Patch the ARB shell script to make sure ARB uses the same perl version at
  # runtime as this formula at build time. This patch will not be submitted to
  # upstream (decision made with the ARB team). The brew audit (brew audit
  # --new-formula arb) will complain about the patch, the three corresponding
  # errors in the report can be ignored.
  patch :DATA

  ##############################################################################
  ### INSTALL                                                                ###
  ##############################################################################
  def install
    # set a fixed perl path in the arb script
    which_perl = which("perl").parent.to_path
    inreplace Dir["#{buildpath}/SH/arb"], /___PERL_PATH___/, which_perl
    # on some systems the permissions were incorrect after the patch
    # leading to the symlink in bin not be created -> make sure they are correct
    chmod 0555, "#{buildpath}/SH/arb"

    # make ARB makefile happy
    cp "config.makefile.template", "config.makefile"

    # create header file with revision information when building head
    if build.head?
      cp '/Users/jgerken/Documents/Projects/ARB/sources/trunk/TOOLS/arb_export_newick.cxx', "#{buildpath}/TOOLS/"
      cp '/Users/jgerken/Documents/Projects/ARB/sources/trunk/TOOLS/arb_test.cxx', "#{buildpath}/TOOLS/"
      cp '/Users/jgerken/Documents/Projects/ARB/sources/trunk/TOOLS/Makefile', "#{buildpath}/TOOLS/"
      cp '/Users/jgerken/Documents/Projects/ARB/sources/trunk/BINDEP/needs_libs.arb_export_newick', "#{buildpath}/BINDEP/"
      cp '/Users/jgerken/Documents/Projects/ARB/sources/trunk/SOURCE_TOOLS/dep.alltargets', "#{buildpath}/SOURCE_TOOLS/"
      cp '/Users/jgerken/Documents/Projects/ARB/sources/trunk/Makefile', "#{buildpath}/"
      cp '/Users/jgerken/Documents/Projects/ARB/sources/trunk/UNIT_TESTER/Makefile.test', "#{buildpath}/UNIT_TESTER/"
      # Replace GV
      # cp '/Users/jgerken/Documents/Projects/ARB/sources/trunk/ARBDB/adsocket.cxx', "#{buildpath}/ARBDB/"
      #
      # cp '/Users/jgerken/Documents/Projects/ARB/sources/trunk/CORE/arb_strbuf.cxx', "#{buildpath}/CORE/"
      # cp '/Users/jgerken/Documents/Projects/ARB/sources/trunk/NTREE/NT_sort.cxx', "#{buildpath}/NTREE/"
      cp '/Users/jgerken/Documents/Projects/ARB/sources/trunk/PERL_SCRIPTS/ARBTOOLS/TESTS/automatic.pl', "#{buildpath}/PERL_SCRIPTS/ARBTOOLS/TESTS/"

      (buildpath/"TEMPLATES/svn_revision.h").write <<~EOS
        #define ARB_SVN_REVISION      "#{version}"
        #define ARB_SVN_BRANCH        "trunk"
        #define ARB_SVN_BRANCH_IS_TAG 0
      EOS
    end

    # build options
    args = %W[
      ARB_64=1
      OPENGL=#{build.with?("open-gl") ? 1 : 0}
      MACH=DARWIN
      DARWIN=1
      LINUX=0
      DEBIAN=0
      REDHAT=0
      DEBUG=#{build.with?("debug") ? 1 : 0}
    ]

    # environment variables required by the build
    ENV["ARBHOME"] = buildpath.to_s
    ENV.prepend_path "PATH", "#{buildpath}/bin"

    # build
    if build.with? "test"
      # TODO: remove when current devel version is released as stable
      if build.stable?
        odie "Option --with-test is not avaible for the stable version."
      end
      opoo "The option --with-test is intended for developer use only. It may fail your build. If it does, install ARB without the option."
      system "make", "rebuild", "UNIT_TESTS=1", *args
    end

    system "make", "rebuild", *args

    # install
    prefix.install "bin"
    prefix.install "lib"
    prefix.install "GDEHELP"
    prefix.install "PERL_SCRIPTS"
    prefix.install "SH"
    prefix.install "demo.arb"
    (lib/"help").install "HELP_SOURCE/oldhelp"

    # some perl scripts use /usr/bin/perl which does not work with ARB on MacOS
    # make all scripts use the perl version from the environment
    inreplace Dir["#{prefix}/PERL_SCRIPTS/**/*.pl"], %r{^#! */usr/bin/perl *$|^#! *perl *$}, "#!/usr/bin/env perl"

    if build.head?
      ohai "Verify ARB perl bindings"
      system "ARBHOME=\"#{prefix}\" perl #{prefix}/PERL_SCRIPTS/ARBTOOLS/TESTS/automatic.pl -client homebrew -db #{prefix}/demo.arb"
    end
  end

  def post_install
    # make directory for pt_server
    (lib/"pts").mkpath
    # pt_server expects that everyone can read and write
    chmod 0777, lib/"pts"
    # make PT server configuration writeable
    chmod 0666, lib/"arb_tcp.dat"
  end

  def caveats; <<~EOS
    - run ARB by typing arb
    - a demo database is installed in #{prefix}/demo.arb
    - for information how to install different versions of ARB via Homebrew see
      https://github.com/arb-project/homebrew-arb
    - more information about ARB can be found at http://www.arb-home.de
    - to get help you may join the ARB mailing list, see
      http://bugs.arb-home.de/wiki/ArbMailingList for details
    - to report bugs in ARB see http://bugs.arb-home.de/wiki/BugReport
    - you can set up keyboard short cuts manually by executing the following
      commands (caution this might interfere with keybord configurations you
      have set up for other X11 programs on your Mac):

      xmodmap -e "clear Mod1"
      xmodmap -e "clear Mod2"
      xmodmap -e "add Mod1 = Meta_L"
      xmodmap -e "add Mod1 = Meta_R"
      xmodmap -e "add Mod2 = Mode_switch"

      after executing these commands you can use the following short cuts in
      ARB:
        - use CONTROL COMMAND ARROW KEY to jump over bases
        - use OPTION ARROW KEY to pull in bases across alignment gaps
        - use right COMMAND plus a letter key to activate a menu item

    Please cite

    Ludwig, W. et al. ARB: a software environment for sequence data.
    Nucleic Acids Research 32, 1363–1371 (2004).

  EOS
  end

  test do
    system bin/"arb", "help"
  end
end

# make ARB use the bundled PERL version
__END__
diff --git a/SH/arb b/SH/arb
--- a/SH/arb
+++ b/SH/arb
@@ -1,5 +1,7 @@
 #!/bin/bash -u

+export PATH="___PERL_PATH___:$PATH"
+
 # set -x

 # error message function
