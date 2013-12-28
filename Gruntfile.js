module.exports = function(grunt) {
grunt.loadNpmTasks('grunt-contrib-coffee');
  // Project configuration.
  grunt.initConfig({
    coffee: {
      compile: {
        files: {
          'assets/js/client.js': ['assets/coffee/client.coffee']
        }
      }
    }
  });
  // Default task.
  grunt.registerTask('default', 'coffee');
};