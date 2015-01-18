module TwistlockControl
	# A container instance represents a container currently
	# running on a provisioner.
	class ContainerInstance < PersistedEntity
		repository ContainerInstanceRepository

		attribute :id, String, default: :generate_id

		def generate_id
			Digest::SHA256.hexdigest("#{container_id}-#{provisioner_id}")
		end

		# Attributes as dictated by provisioner
		attribute :container_id
		attribute :ip_address
		attribute :provisioner_id
	end
end