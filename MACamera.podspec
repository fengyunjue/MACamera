#
# Be sure to run `pod lib lint MACamera.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'MACamera'
  s.version          = '1.0.1'
  s.summary          = '微信样式小视频录制组件'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
                    模仿微信的界面,制作的小视频录制组件,使用简单
                       DESC

  s.homepage         = 'https://github.com/fengyunjue/MACamera'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'fengyunjue' => 'ma772528138@qq.com' }
  s.source           = { :git => 'https://github.com/fengyunjue/MACamera.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'MACamera/Classes/**/*'
  
  s.resource_bundles = {
     'MACamera' => ['MACamera/Assets/*.png']
   }

  s.public_header_files = 'MACamera/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  
end
