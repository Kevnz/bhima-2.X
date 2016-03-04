/* global describe, it, beforeEach */
var chai = require('chai');
var expect = chai.expect;

/** import test helpers */
var helpers = require('./helpers');
helpers.configure(chai);


/**
* The /projects API endpoint
*
* This test suite implements full CRUD on the /projects HTTP API endpoint.
*/
describe('The /employees API endpoint :: ', function () {
  'use strict';

  var agent = chai.request.agent(helpers.baseUrl);

  /** login before each request */
  beforeEach(helpers.login(agent));

  // Custom dates
  var embaucheDate  = new Date('2016-01-01'),
      dob1 = new Date('1987-04-17'),
      dob2 = new Date('1993-04-25');

  // employee we will add during this test suite.
  var employee = {
      code : 'x500',
      prenom : 'Carolus',
      name : 'Magnus',
      postnom : 'Charlemagne',
      sexe : 'M',
      dob : dob1,
      date_embauche : embaucheDate,
      nb_spouse : 0,
      nb_enfant : 0,
      grade_id : '9ee06e4a-7b59-48e6-812c-c0f8a00cf7d3',
      daily_salary : 50,
      bank : 'BIAC',
      bank_account : '00-99-88-77',
      email : 'me@info.com',
      fonction_id : 1,
      locked : 0,
      service_id : 1,
      location_id : 'ffe563ef-781c-4551-a080-7cec135351ff',
      creditor_group_uuid : 'b0fa5ed2-04f9-4cb3-92f7-61d6404696e7',
      debitor_group_uuid : '4de0fe47-177f-4d30-b95f-cff8166400b4'
  };

  var updateEmployee = {
      code : 'x500',
      prenom : 'Charle',
      name : 'Magne',
      postnom : 'De France',
      sexe : 'M',
      dob : dob2,
      date_embauche : embaucheDate,
      nb_spouse : 0,
      nb_enfant : 0,
      grade_id : '9ee06e4a-7b59-48e6-812c-c0f8a00cf7d3',
      daily_salary : 50,
      bank : 'BIAC',
      bank_account : '00-99-88-77',
      email : 'me@info.com',
      fonction_id : 1,
      service_id : 1,
      location_id : 'ffe563ef-781c-4551-a080-7cec135351ff',
      creditor_group_uuid : 'b0fa5ed2-04f9-4cb3-92f7-61d6404696e7',
      debitor_group_uuid : '4de0fe47-177f-4d30-b95f-cff8166400b4'

  };

  it('METHOD : POST PATH : /employee,  should create a new employee', function () {
    return agent.post('/employees')
      .send(employee)
      .then(function (res) {
        expect(res).to.have.status(201);
        expect(res).to.be.json;
        expect(res.body.id).to.exist;
        employee.id = res.body.id;
      })
      .catch(helpers.handler);
  });

  it('METHOD : POST PATH : /employee,  with fake employee data', function () {
    return agent.post('/employees')
      .send({})
      .then(function (res) {
        expect(res).to.have.status(400);
        expect(res).to.be.json;
      })
      .catch(helpers.handler);
  });

  it('METHOD : GET PATH : /employees,  returns a list of all employees', function () {
    return agent.get('/employees')
      .then(function (res) {
        expect(res).to.have.status(200);
        expect(res.body).to.not.be.empty;
      })
      .catch(helpers.handler);
  });

  it('METHOD : GET PATH : /employees/:id,  should return a specific employee ', function () {
    return agent.get('/employees/' + employee.id)
      .then(function (res) {
        var emp = res.body;
        expect(res).to.have.status(200);
        expect(res).to.be.json;
        expect(emp).to.be.a('object');

        // add a missing property due to alias in db query
        emp.code = emp.code_employee;
        expect(emp).to.contain.all.keys(employee);
      })
      .catch(helpers.handler);
  });

  it('METHOD : GET PATH : /employees/code/:value,  should return a list of employees match the employee code token', function () {
    return agent.get('/employees/code/' + String(employee.code).substring(0,1))
      .then(function (res) {
        expect(res).to.have.status(200);
        expect(res).to.be.json;
        expect(res.body).to.not.be.empty;
      })
      .catch(helpers.handler);
  });

  it('METHOD : GET PATH : /employees/names/:value,  should return a list of employees match the employee names token', function () {
    return agent.get('/employees/names/' + employee.name.substring(0,2))
      .then(function (res) {
        expect(res).to.have.status(200);
        expect(res).to.be.json;
        expect(res.body).to.not.be.empty;
      })
      .catch(helpers.handler);
  });

  it('METHOD : GET PATH : /employees/unknown/:value,  should return an error for an ankwnow key', function () {
    return agent.get('/employees/unknown/' + employee.name.substring(0,2))
      .then(function (res) {
        expect(res).to.have.status(400);
        expect(res).to.be.json;
      })
      .catch(helpers.handler);
  });

  it('METHOD : GET PATH : /employees/code/:value,  should return an empty array for an unmatch value', function () {
    return agent.get('/employees/code/unknown')
      .then(function (res) {
        expect(res).to.have.status(200);
        expect(res).to.be.json;
        expect(res.body).to.have.length(0);
      })
      .catch(helpers.handler);
  });


  it('METHOD : PUT PATH : /employee/:id,  should update an existing employee ', function () {
    return agent.put('/employees/' + employee.id)
      .send(updateEmployee)
      .then(function (res) {
        var emp = res.body;
        expect(res).to.have.status(200);
        expect(res).to.be.json;
        expect(emp).to.be.a('object');
        checkValidUpdate(emp, updateEmployee);
      })
      .catch(helpers.handler);
  });

  it('METHOD : PUT PATH : /employee/:id should not update an existing employee with a fake Id ', function () {
    return agent.put('/employees/fakeId')
      .send(updateEmployee)
      .then(function (res) {
        expect(res).to.have.status(404);
      })
      .catch(helpers.handler);
  });

  it('METHOD : PUT PATH : /employee/:idb should not update an existing employee with fake fields ', function () {
    return agent.put('/employees/' + employee.id)
      .send({
        code : 'NEW_CODE_X',
        fakeAttribute1: 'fake value 1',
        fakeAttribute2: 'fake value 2'
      })
      .then(function (res) {
        expect(res).to.have.status(400);
        return agent.get('/employees/' + employee.id);
      })
      .then(function (res) {
        var emp = res.body;
        expect(res).to.have.status(200);
        expect(res).to.be.json;
        expect(emp).to.be.a('object');
        checkValidUpdate(emp, updateEmployee);
      })
      .catch(helpers.handler);
  });

  /**
  * @function checkValidUpdate
  * @desc This function test if an updated value returned by the server
  * correspond correctly to the update sended
  * @param {object} emp The employee object to test
  * @param {object} update The correct employee update
  */
  function checkValidUpdate(employee, update) {
    // add a missing property due to alias in db query
    employee.code = employee.code_employee;
    expect(employee).to.contain.all.keys(update);

    /** @fixme -- manual treatment of dates is sub-optimal.  Can we do better? */
    for (var i in update) {
      if (i === 'dob' || i === 'date_embauche') {
        expect(new Date(employee[i])).to.equalDate(new Date(update[i]));
      } else {
        expect(employee[i]).to.equal(update[i]);
      }
    }
  }

});
