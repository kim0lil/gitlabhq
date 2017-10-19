module Gitlab
  module Metrics
    class SidekiqTransaction < Transaction
      def initialize(worker_class)
        super()
        @worker_class = worker_class
      end

      protected

      def labels
        { controller: @worker_class.name, action: 'perform' }
      end
    end
  end
end
