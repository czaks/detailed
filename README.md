detailed
========

Compromise between single and multiple table inheritance with ActiveRecord. This gem doesn't
depend on Rails at all (that's, in fact, how it originated).

With this gem you can have a table hierarchy like this:
    user (id, type (class), login, password)
    |- user_client_details (client_id, billing_address, phone_number)
    |- user_worker_details (worker_id, wage, bank_account)
    `- user_supplier_details (supplier_id, company_name)

And models hierarchy like this:
    ActiveRecord::Base
    |- User
    |  |- Client
    |  |- Worker
    |  `- Supplier
    |- UserWorkerDetail
    |- UserClientDetail
    `- UserSupplierDetail

All detail classes would look like this (nothing more is needed):
    UserWorkerDetail < ActiveRecord::Base
      belongs_to :worker
    end

The main class should be in this form:
    class User < ActiveRecord::Base
      # ... your code here ...

      include Detailed
    end

The subclasses should be in this form:
    class Client < User
      request_details

      # ... your code here ...
    end
    
To add this package to your environment, add the following line to your Gemfile:
    gem "detailed"

This gem started from this post on StackExchange: http://stackoverflow.com/a/1634734/3256901 .


Access to detailed properties
-----------------------------
With the tableset above, we can access our variables directly, like
    client = new Client
    client.login = "teh1234"              # a field of user
    client.billing_address = "Zgoda 18/2" # a field of user_client_details
    client.save

Be aware, that you can't issue find/where with extended fields at the current
time. You need to resort to the regular:
    Client.find("details_of_client.billing_address" => "Zgoda 18/2")


Subclasses' associations
------------------------
Your subclasses can have relations directly, without touching the detail models (even
though their tables will carry the foreign keys).

Let's suppose, that your Worker has one avatar...

    class Worker < User
      ...
      request_details
      has_one :avarar
      ...
    end

On the way back, this is a bit more complicated:

    class Avatar < ActiveRecord::Base
      ...
      belongs_to :worker, foreign_key: "user_worker_details.avatar_id"
      ...
    end

Please be aware, that the "dot notation" of the foreign key is an extension to
ActiveRecord provided by this gem.

NB.: Other sorts of associations than has_one are currently untested.


N+1 query problem
-----------------
This is an optimization problem. When you want to list all your users, casting
them to appropriate models and fetching their details, you can do:
    
    User.all

Unfortunately, this method causes you to do N+1 queries (one for all users, and
each another one for details). This is because ActiveRecord doesn't know a class
of a given record in advance.

On the other hand, you can instruct ActiveRecord, that all details will be needed
by issuing this call:

    User.all_with_details

ActiveRecord will now run 1+m queries, where m is the number of subclasses, so
for our users it will be 4 queries.


Subclasses without details
--------------------------
Sometimes you are going to subclass the main model without the need for additional
fields. This is easy, you just do

class BasicUser < User
end

No further code needed, detailed won't go into your way.


Subclasses of subclasses
------------------------
This is currently not tested nor supported, though possible with small changes to
this code. Patches are welcome.


License
-------
This code is licensed under the MIT license. See file COPYING for details.
