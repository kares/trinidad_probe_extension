require 'trinidad_probe_extension/version'

module Trinidad
  module Extensions
    class ProbeServerExtension < ServerExtension

      # @override
      def configure(tomcat)
        if disabled?
          logger.info "Skipped configuration of probe extension"
          return
        end

        set_tomcat_class_loader tomcat
        @@tomcat = tomcat
        if self.class.probe_name.nil?
          deploy_probe = configure_probe(@options)
          @@probe_name = deploy_probe.probe_name
          tomcat.host.add_container_listener deploy_probe
        end
      end

      # @private
      @@probe_name = nil
      def self.probe_name; @@probe_name end

      # @private
      @@tomcat = nil
      # @private HACK - HACH - HACK
      def self.tomcat; @@tomcat end

      protected

      # Configured the probe application based on the passed configuration.
      def configure_probe(config)
        default_span = '6h'
        defaults = { # all "com.googlecode.psiprobe.beans.stats." prefix :
          # every 30 seconds for x hours
          'collectors.connector.period' => 30, # '30s'
          'collectors.connector.phase' => 0, # '0s'
          'collectors.connector.span' => default_span,
          # every 30 seconds for x hours
          'collectors.memory.period' => 30, # '30s'
          'collectors.memory.phase' => 0,
          'collectors.memory.span' => default_span,
          # every 30 seconds for x hours
          'collectors.runtime.period' => 30, # '30s'
          'collectors.runtime.phase' => 0,
          'collectors.runtime.span' => default_span,

          # every 60 seconds for 1 hour
          #'collectors.cluster.period' => 60,
          #'collectors.cluster.phase' => 0,
          #'collectors.cluster.span' => '1h',

          'collectors.app.selfIgnored' => true,
          #
          'collectors.app.period' => 60,
          'collectors.app.phase' => 0,
          'collectors.app.span' => default_span,
          #
          'collectors.datasource.period' => 60,
          'collectors.datasource.phase' => 0,
          'collectors.datasource.span' => default_span,

          'listeners.flapInterval' => '20',
          'listeners.flapStartThreshold' => '0.2',
          'listeners.flapStopThreshold' => '0.5',
          'listeners.flapLowWeight' => '1',
          'listeners.flapHighWeight' => '1',
        }

        defaults.each do |key, value|
          name = "com.googlecode.psiprobe.beans.stats.#{key}"
          unless Java::JavaLang::System.get_property(name)
            value = "#{value}s" if value.is_a?(Integer)
            Java::JavaLang::System.set_property(name, value.to_s)
          end
        end

        probe_name = probe_context_name(config)
        probe_path = config[:context_path] if config.is_a?(Hash)
        probe_path ||= probe_name

        Deployer.new(probe_name, probe_path)
      end

      def probe_context_name(config, default = '/__probe__')
        return config.to_s if config.is_a?(String) || config.is_a?(Symbol)
        config[:context_name] || config[:context_path] || default
      end

      private

      def set_tomcat_class_loader(tomcat) # compatibility with latest Trinidad
        tomcat_loader = tomcat.server.getParentClassLoader
        if tomcat_loader.nil? || tomcat_loader == Java::JavaLang::ClassLoader.getSystemClassLoader
          tomcat.server.setParentClassLoader JRuby.runtime.jruby_class_loader
        end
      end

      def disabled?
        property = Java::JavaLang::System.getProperty('trinidad.extensions.probe')
        property ? Java::JavaLang::Boolean.parseBoolean(property) : nil
      end

      def logger
        org.apache.juli.logging.LogFactory.getLog('org.apache.catalina.startup.Tomcat')
      end

      APP_PATH = File.expand_path('../app', File.dirname(__FILE__))
      # JARS_DIR = File.expand_path('../trinidad-libs', File.dirname(__FILE__))

      # @private support for "eager" deployment mostly for testing it out
      EAGER = Java::JavaLang::Boolean.getBoolean('trinidad.extensions.probe.eager')

      # Does the deployment of the probe application.
      # @note This extension maintains compatibility with "old" 1.0.x Trinidad.
      class Deployer
        include Trinidad::Tomcat::LifecycleListener
        include Trinidad::Tomcat::ContainerListener

        # @private
        CONTAINER = Trinidad::Tomcat::Container

        def initialize(name, path, options = nil)
          @probe_name, @probe_path = name, path
        end

        def probe_name; @probe_name end

        def containerEvent(event)
          case event.type # ContainerEvent
          when CONTAINER::ADD_CHILD_EVENT then
            if ( context = event.data ).is_a?(Trinidad::Tomcat::Context)
              # @host ||= event.container
              # start once-only after the (first) web-app context boots :
              event.container.remove_container_listener self
              context.add_lifecycle_listener self
              # NOTE: this could be improved for multi-apps e.g. in case first
              # web-app fails to start up wwe might still want to start probe
            end
          end
        end

        def lifecycleEvent(event)
          context = event.lifecycle
          if Trinidad::Tomcat::Lifecycle::BEFORE_START_EVENT == event.type
            # Dir.glob("#{JARS_DIR}/*.jar").each { |jar| load jar }
            load_ecj # and make sure JSP compilation will work :
            # Java::JavaLang::Class.forName 'org.apache.jasper.compiler.JDTCompiler'
            do_deploy!(context) if EAGER
          end
          if Trinidad::Tomcat::Lifecycle::AFTER_START_EVENT == event.type
            do_deploy!(context) unless EAGER
          end
        rescue => e
          context.logger.warn "Setting up probe application failed: #{e.inspect}" <<
                              "\n  #{e.backtrace.join("\n  ")}"
        rescue Java::JavaLang::Exception => e
          context.logger.warn "Setting up probe application failed: ", e
        end

        def deploy!(logger = nil)
          logger.info "Deploying probe application under: #{@probe_path}" if logger

          tomcat = ProbeServerExtension.tomcat

          dummy_host = org.apache.catalina.Host.impl {}
          # NOTE: due "old" Tomcat compatibility use (host, url, path) :
          probe_context = tomcat.addWebapp(dummy_host, @probe_path, APP_PATH)
          probe_context.name = @probe_name if @probe_name
          probe_context.privileged = true # TODO allow tomcat security
          tomcat.host.addChild(probe_context)

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

        private

        def do_deploy!(context)
          context.remove_lifecycle_listener self
          deploy!(context.logger)
        end

      end

    end
  end
end