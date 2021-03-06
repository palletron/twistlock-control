Given(/^(?:a|the) user has defined a service$/) do
	dir = Dir.pwd + '/../redis-container'
	@service = Actions::Container.add(name: 'redis', url: dir)
end

Given(/^a provisioner is configured$/) do
	@provisioner = Actions::Provisioner.add(name: 'my-provisioner', url: 'localhost')
end

Given(/^(?:a|the) user has created an instance of that service$/) do
	@service_instance = Actions::ServiceInstance.add('my-instance', @service)
end

Then(/^(?:a|the) user should be presented with a configurable representation of the service$/) do
	@container_configuration = @service_instance.container_configurations.first
end

When(/^(?:a|the) user configures the service instance$/) do
	@container_configuration.provisioner = @provisioner
end

When(/^(?:a|the) user gives the provision command$/) do
	api_double = double
	expect(api_double).to receive(:provision_container).and_return({})
	expect(@provisioner).to receive(:api).and_return(api_double)
	Actions::ContainerInstance.add(@container_configuration)
end

Then(/^a container instance should be provisioned$/) do
	expect(Entities::ContainerInstance.all.length).to equal(1)
end
