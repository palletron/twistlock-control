module TwistlockControl
	# A CompositeService is a service that consists of a number of services working together to
	# provide a single service. For example a web forum service might consist of a MySQL service,
	# for persistant storage, and a Ruby HTTP service that serves HTML sites and queries the storage.
	# In the CompositeService you may choose to only expose the HTTP service, making it only possible
	# to query the MySQL database through the Ruby application, which might be considered proper
	# encapsulation.
	class CompositeService < Service
		attribute :id, String, :default => :generate_id
		attribute :name, String
		attribute :services, [ServiceRelation]

		def generate_id
			name.downcase.gsub(' ','-')
		end

		def add_service(service, name=nil)
			rel = ServiceRelation.new(
				name: name ? name : service.name,
				service_id: service.id
			)
			services.push rel
			save
		end

		def add_mount()
		end

		def add_container(container, name=nil)
			rel = ServiceRelation.new(
				name: name ? name : container.name,
				container_id: container.id
			)
			services.push rel
			save
		end

		def expose(provided_service_name, service)
			provided_services[provided_service_name] = service
			save
		end

		def link(provided_service, consumed_service)
			links.push [provided_service, consumed_service]
			save
		end

		def save
			attrs = self.attributes
			service_attrs = services.map {|s|s.attributes}
			attrs[:services] = service_attrs
			ServiceRepository.save(attrs)
		end

		def remove
			ServiceRepository.remove(id)
		end

		def self.find_by_id(id)
			if attributes = ServiceRepository.find_by_id(id)
				new(attributes)
			else
				nil
			end
		end

		def self.find_with_ids(service_ids)
			ServiceRepository.find_with_ids(service_ids).map {|a| new(a) }
		end

		def self.all()
			ServiceRepository.all.map {|a| new(a) }
		end

		def containers
			services.select(&:is_a_container?).map(&:container)
		end
	end

	class ServiceRelation < Entity
		attribute :name, String
		attribute :container_id, String
		attribute :service_id, String

		def is_a_container?
			!container_id.nil?
		end

		def is_a_service?
			!service_id.nil?
		end

		def container
			Container.find_by_id(container_id)
		end

		def service
			Service.find_by_id(service_id)
		end
	end
end