module TwistlockControl
	#
	# Link cases:
	#
	#   1. Multi-consumer: a webservice might have 10 Ruby frontend apps, all connecting
	#      to the same database. Simply increasing the amount of service instances with
	#      the same links will solve this case. Question: do we want to specify this
	#      possibility in each service link, or can we simply assume all services are
	#      scalable in this way? Not all are, but maybe that's a service property, not
	#      a relation property.
	#   2. Multi-producer: A MongoDB cluster might have multiple master nodes. A Ruby
	#      frontend app may want to connect to any of these. The problem is that it will
	#      have to know before starting on which ports this potentially infinite number
	#      of servers has, and somehow choose between them. A solution might be to couple
	#      each Ruby app with a random master.
	#
	# I have the feeling this isn't something that should be stored in the relation either.
	class ServiceRelation < Entity
		attribute :service_id, String

		def service
			Service.find_by_id(service_id)
		end
	end

	class ServiceLink < Entity
		attribute :provider_name, String
		attribute :consumer_name, String
		attribute :provider_service_name, String
		attribute :consumer_service_name, String
	end
	# A CompositeService is a service that consists of a number of services working together to
	# provide a single service. For example a web forum service might consist of a MySQL service,
	# for persistant storage, and a Ruby HTTP service that serves HTML sites and queries the storage.
	# In the CompositeService you may choose to only expose the HTTP service, making it only possible
	# to query the MySQL database through the Ruby application, which might be considered proper
	# encapsulation.
	#
	# Relations between services are described by the links attribute. A link is characterized by
	# a producer and a consumer, the consumer will connect to the producers provided service.
	class CompositeService < Service
		attribute :service_type, Symbol, :default => :composite
		attribute :id, String, :default => :generate_id
		attribute :name, String
		attribute :service_relations, [ServiceRelation]
		attribute :links, [ServiceLink]

		def services
			service_relations.map(&:service)
		end

		def generate_id
			name.downcase.gsub(' ','-')
		end

		def add_service(service, name=nil)
			rel = ServiceRelation.new(
				name: name ? name : service.name,
				service_id: service.id
			)
			service_relations.push rel
			save
		end

		def containers
			result = []
			services = self.services.map(&:service)
			composites = services.select{|s| s.service_type == :composite}
			containers = services.select{|s| s.service_type == :container}
			result += containers
			composites.each do |c|
				result += c.containers
			end
			result
		end

		def expose(provided_service_name, service)
			raise "Implement expose properly"
		end

		def link(provider, provider_service_name, consumer, consumer_service_name)
			links.push ServiceLink.new(
				provider_name: provider.name,
				provider_service_name: provider_service_name,
				consumer_name: consumer.name,
				consumer_service_name: consumer_service_name)
			save
		end

		def save
			ServiceRepository.save(serialize)
		end

		def serialize
			attrs = self.attributes.dup
			service_attrs = service_relations.map {|s|s.attributes}
			links_attrs = links.map {|l|l.attributes}
			attrs[:service_relations] = service_attrs
			attrs[:links] = links_attrs
			attrs
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
	end

end
