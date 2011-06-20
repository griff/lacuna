require 'lacuna/configuration'

describe 'Lacuna configuration' do
  
  after do
    Lacuna::Configuration.clear
  end

  it "yields the defaults to block" do
    Lacuna::Configuration.defaults do |c|
      Lacuna::Configuration.defaults.should be(c)
    end
  end
    
  it "returns the same groups for all the different accessors" do
    Lacuna::Configuration.defaults do |c|
      c[:tt].should be(c.tt)
      c['tt'].should be(c.tt)
      c[:tt, :ttr].should eq([c.tt, c.ttr])
    end
  end
  
  it "yields the group to block" do
    Lacuna::Configuration.defaults do |c|
      c.tt do |g|
        c.tt.should eql(g)
      end
    end
  end
  
  it "returns the same references for all the different accessors" do
    Lacuna::Configuration.defaults do |c|
      c.tt do |g|
        g[:dir].should eql(g.dir)
        g['dir'].should eql(g.dir)
        c.tt(:dir).should eql(g.dir)

        g[:dir, :more].should eql([g.dir, g.more])
        c.tt(:dir, :more).should eql([g.dir, g.more])
      end
    end
  end
  
  it "fails with MissingConfigKeyError when trying to resolve unknown option" do
    expect { Lacuna::Configuration.defaults.g.tt.to_s }.to raise_error(Lacuna::MissingConfigKeyError)
  end

  it "reports unknown option as undefined" do
    Lacuna::Configuration.defaults.g.tt.defined?.should be(false)
  end

  it "reports unknown option as invalid" do
    Lacuna::Configuration.defaults.g.tt.valid?.should be(false)
  end

  it "assigns value to option using mutator" do
    Lacuna::Configuration.defaults.tt do |g|
      g.bin = 'blom'
      g.bin.to_s.should eql('blom')
    end
  end
        
  it "assigns value to option using bracket mutator and symbol key" do
    Lacuna::Configuration.defaults.tt do |g|
      g[:bin] = 'blom'
      g.bin.to_s.should eql('blom')
    end
  end

  it "assigns value to option using bracket mutator and string key" do
    Lacuna::Configuration.defaults.tt do |g|
      g['bin'] = 'blom'
      g.bin.to_s.should eql('blom')
    end
  end

  it "reports option with assigned value as defined" do
    Lacuna::Configuration.defaults.tt do |g|
      g.bin = 'blom'
      g.bin.defined?.should be(true)
    end
  end

  it "reports option with assigned value without references as valid" do
    Lacuna::Configuration.defaults.tt do |g|
      g.bin = 'blom'
      g.bin.valid?.should be(true)
    end
  end

  it "fails to resolve option that contains references to undefined option" do
    Lacuna::Configuration.defaults.tt do |g|
      g.blob = g.min + '.test'
      expect { g.blob.to_s }.to raise_error(Lacuna::MissingConfigKeyError)
    end
  end

  it "reports option that contains references to undefined option as defined" do
    Lacuna::Configuration.defaults.tt do |g|
      g.blob = g.min + '.test'
      g.blob.defined?.should be(true)
    end
  end

  it "reports option that contains references to undefined option as invalid" do
    Lacuna::Configuration.defaults.tt do |g|
      g.blob = g.min + '.test'
      g.blob.valid?.should be(false)
    end
  end

  it "selects the second operand in a | operation when the option in the first operand is undefined" do
    Lacuna::Configuration.defaults.tt do |g|
      (g.pw | 'file').to_s.should eql('file')
    end
  end

  it "selects the second operand in a | operation when the option in the first operand is undefined" do
    Lacuna::Configuration.defaults.tt do |g|
      g.all = 'file'
      (g.pw | g.all).to_s.should eql('file')
    end
  end

  it "selects the first operand in a | operation when the option in the first operand is defined" do
    Lacuna::Configuration.defaults.tt do |g|
      g.all = 'file'
      g.pw = 'more'
      (g.pw | g.all).to_s.should eql('more')
    end
  end

  it "selects the first operand in a | operation even when the option in the first operand is invalid" do
    Lacuna::Configuration.defaults.tt do |g|
      g.pw = g.all
      expect { (g.pw | 'file').to_s}.to raise_error(Lacuna::MissingConfigKeyError)
    end
  end

  it "ignores the second operand in a | operation when the option in the first operand is defined" do
    Lacuna::Configuration.defaults.tt do |g|
      g.pw = 'more'
      (g.pw | g.all).to_s.should eql('more')
    end
  end

  it "resolves references to other options used with +" do
    Lacuna::Configuration.defaults.tt do |g|
      g.sin = 'file'
      g.mob = g.sin + '.test'
      g.mob.to_s.should eql('file.test')
    end
  end
  
  it "resolves references to other options used with /" do
    Lacuna::Configuration.defaults.tt do |g|
      g.din = 'file'
      g.top = g.din / :test
      g.top.to_s.should eql('file/test')
    end
  end
  
  it "waits to resolve references to other options until a string is required" do
    Lacuna::Configuration.defaults.tt do |g|
      g.ref = g.value
      g.plus = g.value + '.test'
      g.path = g.value / 'test'
      g.ref_select = g.ref | 'file'
      g.select = g.value | 'test'
      expect{ g.ref.to_s }.to raise_error(Lacuna::MissingConfigKeyError)
      expect{ g.plus.to_s }.to raise_error(Lacuna::MissingConfigKeyError)
      expect{ g.path.to_s }.to raise_error(Lacuna::MissingConfigKeyError)
      expect{ g.ref_select.to_s }.to raise_error(Lacuna::MissingConfigKeyError)
      g.select.to_s.should eql('test')

      g.value = 'more'
      g.ref.to_s.should eql('more')
      g.plus.to_s.should eql('more.test')
      g.path.to_s.should eql('more/test')
      g.ref_select.to_s.should eql('more')
      g.select.to_s.should eql('more')
    end
  end

  it "gives access to options defined in defaults from overlay" do
    Lacuna::Configuration.defaults.tt do |g|
      g.tin = 'file'
      g.mob = g.tin + '.test'
    end
    Lacuna.configuration.tt.mob.to_s.should eq('file.test')
  end
  
  it "overrides default option value when using overlay" do
    Lacuna.configuration.tt.lin = 'oakley'
    Lacuna::Configuration.defaults.tt.lin = 'file'
    Lacuna.configuration.tt.lin.to_s.should eq('oakley')
  end
  
  it "resolves references to other options using overlay when accessing the option through there" do
    Lacuna.configuration.tt.lin = 'oakley'
    Lacuna::Configuration.defaults.tt do |g|
      g.lin = 'file'
      g.kvob = g.lin + '.test'
    end
    Lacuna.configuration.tt.kvob.to_s.should eq('oakley.test')
  end
  
  it "only overrides references to other options when accessed through overlay" do
    Lacuna.configuration.tt.quin = 'oakley'
    Lacuna::Configuration.defaults.tt do |g|
      g.quin = 'file'
      g.slob = g.quin + '.test'
      g.slob.to_s.should eq('file.test')
    end
  end
  
  it "fails with MissingConfigKeyError when trying to resolve unknown option in overlay" do
    expect { Lacuna.configuration.g.tt.to_s }.to raise_error(Lacuna::MissingConfigKeyError)
  end

  it "reports unknown option in overlay as undefined" do
    Lacuna.configuration.g.tt.defined?.should be(false)
  end

  it "reports unknown option in overlay as invalid" do
    Lacuna.configuration.g.tt.valid?.should be(false)
  end

  it "can resolve options with unknown references in defaults when those references are defined in the overlay" do
    Lacuna.configuration.tt.lin = 'oakley'
    Lacuna::Configuration.defaults.tt do |g|
      g.kvob = g.lin + '.test'
    end
    expect { Lacuna::Configuration.defaults.tt.kvob.to_s }.to raise_error(Lacuna::MissingConfigKeyError)
    Lacuna.configuration.tt.kvob.to_s.should eq('oakley.test')
  end

  it "reports options with unknown references in defaults as valid when those references are defined in the overlay" do
    Lacuna.configuration.tt.lin = 'oakley'
    Lacuna::Configuration.defaults.tt do |g|
      g.kvob = g.lin + '.test'
    end
    Lacuna::Configuration.defaults.tt.kvob.valid?.should be(false)
    Lacuna.configuration.tt.kvob.valid?.should be(true)
  end
  
end