require 'trinidad'
require 'trinidad_probe_extension/version'

module Trinidad
  module Extensions
    class ProbeWebAppExtension < WebAppExtension

      attr_reader :tomcat

      def configure(tomcat, context)
        @tomcat = tomcat
        context.add_lifecycle_listener configure_probe(@options)
      end

      protected

      def configure_probe(config)
#        default_span = '6h'
#        defaults = { # all "com.googlecode.psiprobe.beans.stats." prefix :
#          # every 30 seconds for x hours
#          'collectors.connector.period' => 30, # '30s'
#          'collectors.connector.phase' => 0, # '0s'
#          'collectors.connector.span' => default_span,
#          # every 30 seconds for x hours
#          'collectors.memory.period' => 30, # '30s'
#          'collectors.memory.phase' => 0,
#          'collectors.memory.span' => default_span,
#          # every 30 seconds for x hours
#          'collectors.runtime.period' => 30, # '30s'
#          'collectors.runtime.phase' => 0,
#          'collectors.runtime.span' => default_span,
#
#          # every 60 seconds for 1 hour
#          #'collectors.cluster.period' => 60,
#          #'collectors.cluster.phase' => 0,
#          #'collectors.cluster.span' => '1h',
#
#          'collectors.app.selfIgnored' => true,
#          #
#          'collectors.app.period' => 60,
#          'collectors.app.phase' => 0,
#          'collectors.app.span' => default_span,
#          #
#          'collectors.datasource.period' => 60,
#          'collectors.datasource.phase' => 0,
#          'collectors.datasource.span' => default_span,
#
#          'listeners.flapInterval' => '20',
#          'listeners.flapStartThreshold' => '0.2',
#          'listeners.flapStopThreshold' => '0.5',
#          'listeners.flapLowWeight' => '1',
#          'listeners.flapHighWeight' => '1',
#        }
#
#        defaults.each do |key, value|
#          name = "com.googlecode.psiprobe.beans.stats.#{key}"
#          unless Java::JavaLang::System.get_property(name)
#            value = "#{value}s" if value.is_a?(Integer)
#            Java::JavaLang::System.set_property(name, value.to_s)
#          end
#        end

        probe_path = config.to_s unless config.is_a?(Hash)
        probe_path ||= config.delete(:context_path) || '/__probe__'
        DeployProbeApp.new(probe_path, tomcat)
      end

      APP_PATH = File.expand_path('../app', File.dirname(__FILE__))
      # JARS_DIR = File.expand_path('../trinidad-libs', File.dirname(__FILE__))

      class DeployProbeApp
        include Trinidad::Tomcat::LifecycleListener

        def initialize(path, tomcat)
          @probe_path = path; @probe_name = 'probe'; @tomcat = tomcat

          tomcat_loader = @tomcat.server.getParentClassLoader
          if tomcat_loader.nil? || tomcat_loader == Java::JavaLang::ClassLoader.getSystemClassLoader
            @tomcat.server.setParentClassLoader JRuby.runtime.jruby_class_loader
          end
        end

        def lifecycleEvent(event)
          context = event.lifecycle
          if Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT == event.type
            # Dir.glob("#{JARS_DIR}/*.jar").each { |jar| load jar }
            load_ecj # and make sure JSP compilation will work :
            Java::JavaLang::Class.forName 'org.apache.jasper.compiler.JDTCompiler'
          end
          if Trinidad::Tomcat::Lifecycle::AFTER_START_EVENT == event.type
            context.remove_lifecycle_listener self
            deploy!(context.logger)
          end
        end

        def deploy!(logger = nil)
          logger.info "Deploying probe application under: #{@probe_path}" if logger

          dummy_host = org.apache.catalina.Host.impl {}
          probe_context = @tomcat.addWebapp(dummy_host, @probe_path, @probe_name, APP_PATH)
          probe_context.privileged = true
          @tomcat.host.addChild(probe_context)

          return probe_context
        end

        def load_ecj
          compiler_class = 'org.eclipse.jdt.core.compiler.batch.BatchCompiler'
          begin
            Java::JavaClass.for_name compiler_class
            return false
          rescue NameError
            require 'ecj/jar'; ECJ.load_jar
            return true
          end
        end

      end

    end
  end
end