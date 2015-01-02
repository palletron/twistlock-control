module TwistlockControl
	class Configuration < Entity
		attribute :service_id

		def serialize
			attributes.dup
		end

		def self.new(attrs)
			if attrs["configurations"] || attrs[:configurations]
				obj = CompositeConfiguration.allocate
			else
				obj = ContainerConfiguration.allocate
			end
			obj.send :initialize, attrs
		end
	end

	class ContainerConfiguration < Configuration
		attribute :provisioner_id

		# Runtime configurable settings
		attribute :mount_points
		attribute :environment_variables

		# Attributes as dictated by provisioner
		attribute :container_id
		attribute :ip_address
	end

	class CompositeConfiguration < Configuration
		attribute :configurations, [Configuration]

		def serialize
			serialized = super
			serialized[:configurations] = configurations.map(&:serialize)
			serialized
		end
	end

	# A service instance is an entity that represents an instance of a service
	# that can be started and stopped. For example, an operator might define a Forum
	# service and then spawn a Forum service instance for each of his customers.
	# Each of the Forum services can be referenced by name and stopped and started
	# independantly, and consist of separate container instances.
	#
	# A service instance has all runtime configuration such as mount points and
	# environment variables.
	#
	# An operator should be able to assign containers to provisioners, and configure
	# their runtime configuration.
	#
	# The configuration has a tree structure. For each composite service there will
	# be a branch element, for every container a leaf. 
	class ServiceInstance < Entity
		attribute :id, String, default: :generate_id
		attribute :name, String
		attribute :service_id, String
		attribute :configuration, Configuration

		# We want to tell all containers how they are linked to eachother.
		# Composite services have the information about which links exist.
		# How many instances there are of a container should be configured
		# at runtime. Can we just do it by adding ContainerConfigurations
		# to a CompositeConfiguration? That would mean the build_configuration
		# method would have to only build composite configurations, leaving
		# the filling in of container configurations to the interactive 
		# resource allocation process. I.E. the user would create a composite
		# configuration, then for each container needed of each composite
		# service they would select on which machine(s) any containers will
		# be ran. When a container configuration is created it can be 
		# determined to which other container configuration it is linked.
		# 
		# So the next step is to change build_configuration to reflect that,
		# then we add methods to CompositeConfiguration that allow to convenient
		# addition of ContainerConfigurations. Including a way to enumerate
		# which containers are needed.
		#
		# We also need to think about the linking, at the moment the provisioner
		# can link a container to any ip address. When the containers are
		# on separate machines, we can not usually link the containers directly
		# on ip, a link would first have to be established. I envisioned this
		# would ideally be through a simple TLS tunnel established by an ambassador
		# container.
		#
		# If we would go for the ambassador approach the Twistlock system would
		# have to be aware of this as it would have to provision ambassador nodes
		# and use the ip addresses of the ambassador nodes to connect across machines.
		#
		# Alternatively, we could assume all machines in the cluster are in the
		# same IP space and simply link them together. This would move the encryption
		# and network management to a separate level and would ideally be a superior
		# architecture, but in practice there is no simple way of achieving this
		# in a way that is compatible with all container providers and all hosts.
		# Since we want Twistlock to be an easy to deploy integrated solution,
		# Twistlock would have to supply an automatic way of configuring such a
		# datacenter without messing with existing architecture too much. A complex
		# task that's not guaranteed to have a perfect solution.
		#
		# We could also for now simply assume a flat ip space, and work on the 
		# ambassador system later.

		def generate_id
			name
		end

		def self.find_by_id(id)
			if attributes = ServiceInstanceRepository.find_by_id(id)
				new(attributes)
			else
				nil
			end
		end

		def self.create(name, service)
			configuration = build_configuration(service)
			instance = new(service_id: service.id, name: name, configuration: configuration)
		end

		def self.build_configuration(service)
			case service.service_type
			when :container
				c = ContainerConfiguration.new(service_id: service.id)
			when :composite
				c = CompositeConfiguration.new(service_id: service.id, configurations: service.services.map{|s| build_configuration(s)})
			else
				raise "Unknown service type: #{service.service_type}"
			end
			c
		end

		# TODO test if building configurations like this works, whether it's sane, whether
		# we can use this to configure for provisioning, and find out and implement how to
		# provision containers from these configuration settings.

		def service
			Service.find_by_id(service_id)
		end

		def serialize
			serialized = attributes.dup
			serialized[:configuration] = configuration.serialize
			serialized
		end

		def save
			ServiceInstanceRepository.save(serialize)
		end

		def remove
			ServiceInstanceRepository.remove(id)
		end
	end
end
